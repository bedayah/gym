import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gim_system/app/app_prefs.dart';
import 'package:gim_system/app/constants.dart';
import 'package:gim_system/app/extensions.dart';
import 'package:gim_system/model/diets_model.dart';
import 'package:gim_system/model/exercises_model.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:gim_system/ui/coach/settings_screens/coach_settings.dart';
import 'package:http/http.dart' as http;
import '../../model/coach_model.dart';
import '../../model/message_model.dart';
import '../../model/user_model.dart';
import '../../ui/coach/home_screens/coach_home.dart';
import '../admin/admin_cubit.dart';
part 'coach_state.dart';

class CoachCubit extends Cubit<CoachState> {
  CoachCubit() : super(CoachInitial());
  static CoachCubit get(context) => BlocProvider.of(context);
  int currentIndex = 0;
  List<Widget> screens = [
    const CochHome(),
    const CoachSettingsScreen(),
  ];
  List titles = [
    'Home',
    'Settings',
  ];
  void changeBottomNavBar(int index) {
    emit(LoadingChangeHomeIndex());
    currentIndex = index;
    emit(ScChangeHomeIndex());
  }

  CoachModel? coachModel;
  Future<void> getCurrentCoachData() async {
    emit(LoadingGetCoach());
    try {
      print("getCurrentCoachData");
      print(AppPreferences.uId);
      var value = await FirebaseFirestore.instance
          .collection(Constants.gym)
          .doc(AppPreferences.gymUid)
          .collection(Constants.coach)
          .doc(AppPreferences.uId)
          .get();
      coachModel = CoachModel.fromJson(value.data() ?? {});
      print("object2");
      print(value.data());
      emit(ScGetCoach());
      print("getCurrentCoachData done");
    } catch (e) {
      print('getCurrentCoachData Error: $e');
      emit(ErorrGetCoach(e.toString()));
    }
  }

  Future<void> editCoach(
      {required CoachModel model, required File? image}) async {
    try {
      emit(LoadingEditCoach());
      var value =
          await FirebaseFirestore.instance.collection('phoneNumbers').get();
      if (model.phone != coachModel!.phone) {
        if (checkPhone(model.phone ?? '', value.docs)) {
          emit(ErorrEditCoach('Phone number is already used'));
          return;
        } else {
          await FirebaseFirestore.instance
              .collection('phoneNumbers')
              .doc(AppPreferences.uId)
              .update({
            'phone': model.phone,
          });
        }
      }
      print(model.toJson());
      await FirebaseFirestore.instance
          .collection(Constants.gym)
          .doc(AppPreferences.gymUid)
          .collection(Constants.coach)
          .doc(AppPreferences.uId)
          .update(model.toJson());
      if (image != null) {
        await addImageSub(
          type: Constants.coach,
          userId: AppPreferences.uId,
          parentImageFile: image,
        );
      }
      print('admin updated Success 😎');
      print('EditCoach userId');
      print(AppPreferences.uId);
      emit(ScEditCoach());
      await getCurrentCoachData();
    } catch (error) {
      print('Error: $error');
      if (error
          .toString()
          .contains('The email address is already in use by another account')) {
        emit(ErorrEditCoach(
            'The email address is already in use by another account'));
      }
      print('Error: $error');
      emit(ErorrEditCoach(error.toString()));
    }
  }

  Future<void> addImageSub(
      {required String type,
      required String userId,
      required File parentImageFile}) async {
    try {
      print('addGuyImage userId');
      print(userId);
      var parentImageUrl = parentImageFile.path;
      var value = await firebase_storage.FirebaseStorage.instance
          .ref()
          .child('images/$userId')
          .putFile(parentImageFile);
      var value2 = await value.ref.getDownloadURL();
      parentImageUrl = value2;
      print('addGuyImage image');
      print(parentImageUrl);
      await FirebaseFirestore.instance
          .collection(Constants.gym)
          .doc(AppPreferences.gymUid)
          .collection(type)
          .doc(userId)
          .update({
        'image': parentImageUrl,
      });
      print('addImage done');
    } catch (e) {
      print('Error: $e');
    }
  }

  List<UserModel> users = [];
  Future<void> getAllusers() async {
    try {
      print("getAllusers");
      var value = await FirebaseFirestore.instance
          .collection(Constants.gym)
          .doc(AppPreferences.gymUid)
          .collection(Constants.user)
          .get();
      for (var element in value.docs) {
        var user = UserModel.fromJson(element.data());
        var dites = await element.reference
            .collection(Constants.dite)
            .orderBy('createdAt', descending: true)
            .get();
        print('dites.docs.length l is ${dites.docs.length}');
        user.dites = [];
        for (var element in dites.docs) {
          var dite = DietModel.fromJson(element.data());
          var value = await FirebaseFirestore.instance
              .collection(Constants.gym)
              .doc(AppPreferences.gymUid)
              .collection(Constants.coach)
              .doc(dite.coachId)
              .get();
          dite.coachModel = CoachModel.fromJson(value.data() ?? {});
          user.dites.orEmpty().add(dite);
        }
        print('dites l is ${user.dites.orEmpty().length}');

        var userExercise = await element.reference
            .collection(Constants.userExercise)
            .orderBy('date', descending: true)
            .get();
        user.userExercises = [];
        for (var element in userExercise.docs) {
          var userExercises = UserExercises.fromJson(element.data());
          var value = await FirebaseFirestore.instance
              .collection(Constants.gym)
              .doc(AppPreferences.gymUid)
              .collection(Constants.coach)
              .doc(userExercises.coachId)
              .get();
          userExercises.coachModel = CoachModel.fromJson(value.data() ?? {});
          userExercises.exercises.orEmpty().forEach((element) async {
            var value2 = await FirebaseFirestore.instance
                .collection(Constants.gym)
                .doc(AppPreferences.gymUid)
                .collection(Constants.exercise)
                .doc(element.exerciseId)
                .get();
            var exerciseModel = ExerciseModel.fromJson(value2.data() ?? {});
            element.exerciseModel = exerciseModel;
          });
          user.userExercises!.add(userExercises);
        }
        print('userExercises l is ${user.userExercises.orEmpty().length}');
        users.add(user);
      }
      print("getAllusers done");
      print(users.length);
    } catch (e) {
      print('Get Parent Data Error: $e');
    }
  }

  List<CoachModel> coachs = [];
  Future<void> getAllCoachs() async {
    try {
      print("getAllcoachs");
      var value = await FirebaseFirestore.instance
          .collection(Constants.gym)
          .doc(AppPreferences.gymUid)
          .collection(Constants.coach)
          .get();
      for (var element in value.docs) {
        coachs.add(CoachModel.fromJson(element.data()));
      }
      print("getAllcoachs done");
      print(coachs.length);
    } catch (e) {
      print('Get Parent Data Error: $e');
    }
  }

  List<ExerciseModel> esercises = [];
  Future<void> getAllesercises() async {
    try {
      print("getAllesercises");
      var value = await FirebaseFirestore.instance
          .collection(Constants.gym)
          .doc(AppPreferences.gymUid)
          .collection(Constants.exercise)
          .get();
      for (var element in value.docs) {
        esercises.add(ExerciseModel.fromJson(element.data()));
      }
      print("getAllesercises done");
      print(esercises.length);
    } catch (e) {
      print('Get Parent Data Error: $e');
    }
  }

  Future<void> getHomeData() async {
    users = [];
    coachs = [];
    esercises = [];
    emit(LoadingGetHomeData());
    try {
      await getAllusers();
      await getAllCoachs();
      await getAllesercises();
      emit(ScGetHomeData());
    } catch (e) {
      print('Get Parent Data Error: $e');
      emit(ErorrGetHomeData(e.toString()));
    }
  }

  Future<void> addDite({required DietModel model}) async {
    try {
      emit(LoadingAddDite());
      var value = FirebaseFirestore.instance
          .collection(Constants.gym)
          .doc(AppPreferences.gymUid)
          .collection(Constants.user)
          .doc(model.userId)
          .collection(Constants.dite)
          .doc();
      model.id = value.id;
      await value.set(model.toJson());
      var indxex = users.indexWhere((element) => element.id == model.userId);
      model.coachModel = coachModel;
      users[indxex].dites.orEmpty().insert(0, model);
      print('Dite added');
      print('dites l is ${users[indxex].dites.orEmpty().length}');
      emit(ScAddDite());
    } catch (error) {
      emit(ErorrAddDite(error.toString()));
      print('Error: $error');
    }
  }

  Future<void> addExercise({required UserExercises model}) async {
    try {
      emit(LoadingAddExercise());
      var doc = FirebaseFirestore.instance
          .collection(Constants.gym)
          .doc(AppPreferences.gymUid)
          .collection(Constants.user)
          .doc(model.userId)
          .collection(Constants.userExercise)
          .doc();
      model.id = doc.id;
      await doc.set(model.toJson());
      var indxex = users.indexWhere((element) => element.id == model.userId);
      users[indxex].userExercises.orEmpty().insert(0, model);
      users[indxex].userExercises.orEmpty().forEach((element) async {
        element.coachModel = coachModel;
        element.exercises.orEmpty().forEach((element) async {
          var value2 = await FirebaseFirestore.instance
              .collection(Constants.gym)
              .doc(AppPreferences.gymUid)
              .collection(Constants.exercise)
              .doc(element.exerciseId)
              .get();
          var exerciseModel = ExerciseModel.fromJson(value2.data() ?? {});
          element.exerciseModel = exerciseModel;
        });
      });
      print('Exercise added');
      print('Exercises l is ${users[indxex].userExercises.orEmpty().length}');
      emit(ScAddExercise());
    } catch (error) {
      emit(ErorrAddExercise(error.toString()));
      print('Error: $error');
    }
  }

  Future<void> updateUserFitnessInfo(
      {required UserModel newModel, required UserModel oldModel}) async {
    try {
      print(newModel.id);
      emit(LoadingUpdateUserFitnessInfo());
      await FirebaseFirestore.instance
          .collection(Constants.gym)
          .doc(AppPreferences.gymUid)
          .collection(Constants.user)
          .doc(newModel.id)
          .update(newModel.toJson());
      print('ScUpdateUserFitnessInfo');
      oldModel.goal = newModel.goal;
      oldModel.fitnesLevel = newModel.fitnesLevel;
      oldModel.height = newModel.height;
      oldModel.weight = newModel.weight;
      oldModel.bodyFatPercentage = newModel.bodyFatPercentage;
      emit(ScUpdateUserFitnessInfo());
    } catch (error) {
      emit(ErorrUpdateUserFitnessInfo(error.toString()));
      print('Error: $error');
    }
  }

  Future<void> sendMessage(
      {required MessageModel messageModel, File? file}) async {
    try {
      emit(LoadingCoachSendMessage());
      if (file != null) {
        messageModel.file = await uploadFile(file);
      }
      var value = FirebaseFirestore.instance
          .collection(Constants.gym)
          .doc(AppPreferences.gymUid)
          .collection(Constants.coach)
          .doc(coachModel!.id)
          .collection(Constants.chats)
          .doc(messageModel.userId)
          .collection(Constants.messages)
          .doc();
      messageModel.id = value.id;
      await value.set(messageModel.toMap());
      var value1 = FirebaseFirestore.instance
          .collection(Constants.gym)
          .doc(AppPreferences.gymUid)
          .collection(Constants.user)
          .doc(messageModel.userId)
          .collection(Constants.chats)
          .doc(coachModel!.id)
          .collection(Constants.messages)
          .doc();
      messageModel.id = value1.id;
      await value1.set(messageModel.toMap());
      emit(ScCoachSendMessage());
    } catch (error) {
      emit(ErorrCoachSendMessage(error.toString()));
      print('Error: $error');
    }
  }

  Future<String?> uploadFile(File file) async {
    try {
      emit(LoadingUploadFile());
      var value = await firebase_storage.FirebaseStorage.instance
          .ref()
          .child('files/${file.path.split('/').last}')
          .putFile(file);
      emit(ScUploadFile());
      return value.ref.getDownloadURL();
    } catch (e) {
      emit(ErorrUploadFile(e.toString()));
      return null;
    }
  }

  List<MessageModel> messages = [];
  Future<void> getMessages({required UserModel userModel}) async {
    try {
      emit(LoadingCoachGetdMessages());
      FirebaseFirestore.instance
          .collection(Constants.gym)
          .doc(AppPreferences.gymUid)
          .collection(Constants.coach)
          .doc(coachModel!.id)
          .collection(Constants.chats)
          .doc(userModel.id)
          .collection(Constants.messages)
          .orderBy('dateTime')
          .snapshots()
          .listen((event) {
        messages = [];
        for (var element in event.docs) {
          messages.add(MessageModel.fromJson(element.data()));
        }
        emit(ScCoachGetdMessages());
      });
      emit(ScCoachGetdMessages());
    } catch (error) {
      emit(ErorrCoachGetdMessages(error.toString()));
      print('Error: $error');
    }
  }

  void sendNotificationsToUser() async {
    // Get all the parent documents from the parent collection
    var userDocs = await FirebaseFirestore.instance
        .collection(Constants.gym)
        .doc(AppPreferences.gymUid)
        .collection(Constants.user)
        .get();
    // Get all the token documents from the token collection
    var tokenDocs = await FirebaseFirestore.instance.collection('tokens').get();
    // Convert the token documents to a map for easier lookup later
    var tokensMap = {for (var doc in tokenDocs.docs) doc['id']: doc['token']};

    // Loop through each parent document
    for (var userDoc in userDocs.docs) {
      var usertId = userDoc.id;
      if (tokensMap.containsKey(usertId)) {
        var token = tokensMap[usertId];
        // Send a notification to the parent's token
        sendNotificationToUser(token);
      } else {
        print('No token found for user $usertId');
      }
    }
  }

  String TOKEN_MESSAGE =
      "key=AAAArRR-L4o:APA91bFIDIihAOvoDnrpGUlWFG9k2XUKmeWht8sIQD_zGfBz35anNyaQyjJscLEByBolXR9oeoSC7CqNTdBlfZaEq2yPCtdDvPK2e1GhOL5Jjgv0cVKjzvzgP7q6HlryEkO5ws1BgJHM";

  void sendNotificationToUser(String token) async {
    var response = await http.post(
      Uri.parse("https://fcm.googleapis.com/fcm/send"),
      headers: <String, String>{
        "content-type": "application/json",
        "Authorization": TOKEN_MESSAGE,
      },
      body: jsonEncode({
        "to": token,
        "notification": {
          "body":
              "👋 A new activity has been added. Log in to your account to view the details and participate.",
          "title": "New Activity Added🎉"
        },
      }),
    );
    // Check the response for errors or other information
    print(response.body);
  }
}
