import 'dart:developer' as developer;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:freibad_app/models/appointment.dart';
import 'package:freibad_app/models/person.dart';
import 'package:freibad_app/models/request.dart';
import 'package:freibad_app/models/session.dart';
import 'package:freibad_app/services/api_service.dart';
import 'package:freibad_app/services/storage_service.dart';
import 'package:uuid/uuid.dart';

class SessionData with ChangeNotifier {
  final bool useAPIService;
  final bool useStorageService;

  List<Person> _persons;
  List<Session> _appointments;
  List<Request> _requests;
  List<String> _availableLocations;

  List<Person> get persons => [..._persons];
  List<Session> get appointments => [..._appointments];
  List<Request> get requests => [..._requests];
  List<String> get availableLocations => [..._availableLocations];

  StorageService db;
  //use LocalStorage for production, use FakeLocalStorage for web

  Uuid uuid = Uuid(); // for creating unique ids

  SessionData({this.useAPIService = false, this.useStorageService = false}) {
    if (useStorageService)
      db = LocalStorage();
    else
      db = FakeLocalStorage();
  }

  Future<void> fetchAndSetData() async {
    await db.setUpDB(); //loads DB
    _persons = await db.getPersons() ?? [];
    _appointments = await db.getAppointment() ?? [];
    _requests = await db.getRequests() ?? [];
    developer.log('fetching and setting local data finished');

    //look for updates for requests
    for (Request request in _requests) {
      if (!useStorageService || kIsWeb)
        break; //do not make server request with wrong data or if data gets loaded from the server anyway
      if (request.hasFailed) continue;

      try {
        Session session = (useAPIService
            ? await APIService.getReservation(request.id)
            : await FakeAPIService.getReservation(request.id));

        if (session is Request) continue;

        _addAppointment(
          id: session.id,
          accessList: session.accessList,
          startTime: session.startTime,
          endTime: session.endTime,
          location: session.location,
        );
        deleteRequest(session.id);
      } catch (exception) {
        developer.log('Something went wrong updating the pending session',
            error: exception);
        continue;
      }
    }
    developer.log('finished updating pending sessions');
    _availableLocations = useAPIService
        ? await APIService.availableLocations()
        : await FakeAPIService.availableLocations();
    developer.log('finished receiving available locations');
    notifyListeners();
  }

  Person findPersonById(String id) {
    if (_persons == null) {
      return null;
    }
    return _persons.firstWhere((element) => element.id == id);
  }

  void addPerson({
    @required String forename,
    @required String name,
    @required String streetName,
    @required String streetNumber,
    @required int postcode,
    @required String city,
    @required String phoneNumber,
    @required String email,
  }) async {
    Person person = Person(
        id: uuid.v1(),
        forename: forename,
        name: name,
        streetName: streetName,
        streetNumber: streetNumber,
        postcode: postcode,
        city: city,
        phoneNumber: phoneNumber,
        email: email);

    try {
      bool apiCallSuccessful = (useAPIService
          ? await APIService.addPerson(person)
          : await FakeAPIService.addPerson(person));
      if (!apiCallSuccessful) return;
      db.addPerson(person);
      _persons.add(person);
      developer.log('added person');
    } catch (exception) {
      print(exception);
      throw exception;
    }
    notifyListeners();
  }

  void updatePerson({
    @required String id,
    String forename,
    String name,
    String streetName,
    String streetNumber,
    int postcode,
    String city,
    String phoneNumber,
    String email,
  }) async {
    Person currentPerson = findPersonById(id);
    Person updatedPerson = Person(
      id: id,
      forename: forename ?? currentPerson.forename,
      name: name ?? currentPerson.name,
      streetName: streetName ?? currentPerson.streetName,
      streetNumber: streetNumber ?? currentPerson.streetNumber,
      postcode: postcode ?? currentPerson.postcode,
      city: city ?? currentPerson.city,
      phoneNumber: phoneNumber ?? currentPerson.phoneNumber,
      email: email ?? currentPerson.email,
    );
    try {
      bool apiCallSuccessful = useAPIService
          ? await APIService.editPerson(updatedPerson)
          : await FakeAPIService.editPerson(updatedPerson);
      if (!apiCallSuccessful) return;

      db.updatePerson(updatedPerson);
      int pos = _persons.indexWhere((element) => element.id == id);
      _persons.replaceRange(pos, pos + 1, [updatedPerson]);
      developer.log('updated person');
    } catch (exception) {
      developer.log(exception);
      throw exception;
    }
    notifyListeners();
  }

  void _addAppointment({
    String id,
    @required List<Map<String, String>> accessList,
    @required DateTime startTime,
    @required DateTime endTime,
    @required String location,
  }) async {
    Appointment appointment = Appointment(
        id: id ?? uuid.v1(),
        accessList: accessList,
        startTime: startTime,
        endTime: endTime,
        location: location);
    try {
      db.addSession(appointment);
      _appointments.add(appointment);
      developer.log('added appointment');
    } catch (exception) {
      developer.log(exception);
      throw exception;
    }
    notifyListeners();
  }

  void addRequest({
    @required List<Map<String, String>> accessList,
    @required DateTime startTime,
    @required DateTime endTime,
    @required String location,
  }) async {
    Request request = Request(
        id: uuid.v1(),
        accessList: accessList,
        startTime: startTime,
        endTime: endTime,
        hasFailed: false,
        location: location);
    try {
      Session resultSession = useAPIService
          ? await APIService.makeReservation(request)
          : await FakeAPIService.makeReservation(request);

      db.addSession(resultSession);

      if (resultSession is Request) {
        _requests.add(resultSession);
        developer.log('added request');
      } else if (resultSession is Appointment) {
        _appointments.add(resultSession);
        developer.log('added appointment');
      } else {
        developer.log(
            'Type of session is not saved. Type: ${resultSession.runtimeType}');
      }
    } catch (exception) {
      developer.log(exception);
      throw exception;
    }
    notifyListeners();
  }

  void deletePerson(String personId) {
    try {
      db.deletePerson(personId);
      _persons
          .removeAt(_persons.indexWhere((element) => element.id == personId));
      developer.log('deleted person');
    } catch (exception) {
      developer.log(exception);
      throw exception;
    }
    notifyListeners();
  }

  void deleteSession(Session session) {
    try {
      if (session is Appointment) {
        deleteAppointment(session.id);
      } else if (session is Request) {
        deleteRequest(session.id);
      } else {
        throw 'Add support to the Database for the children of Sessions';
      }
    } catch (exception) {
      developer.log(exception);
      throw exception;
    }
    notifyListeners();
  }

  Future<void> deleteAppointment(String appointmentId) async {
    int elementPos =
        _appointments.indexWhere((element) => element.id == appointmentId);
    //save appointment, just in case something goes wrong
    Appointment appointmentToDelete = _appointments[elementPos];

    try {
      _appointments.removeAt(elementPos);
      notifyListeners();

      bool apiCallSuccessful = useAPIService
          ? await APIService.deleteReservation(appointmentId)
          : await FakeAPIService.deleteReservation(appointmentId);
      if (!apiCallSuccessful) {
        //api call not successful, add appointment back to list
        developer.log("api call not successful");
        _appointments.add(appointmentToDelete);
        notifyListeners();
        return;
      }

      db.deleteAppointment(appointmentId);
      developer.log('deleted appointment');
    } catch (exception) {
      //add appointment to list, to allow clean removal from server
      _appointments.add(appointmentToDelete);
      notifyListeners();
      developer.log(exception);
      throw exception;
    }
  }

  void deleteRequest(String requestId) async {
    int elementPos = _requests.indexWhere((element) => element.id == requestId);
    //save request, just in case something goes wrong
    Request requestToDelete = _requests[elementPos];

    try {
      _requests.removeAt(elementPos);
      notifyListeners();
      bool apiCallSuccessful = useAPIService
          ? await APIService.deleteReservation(requestId)
          : await FakeAPIService.deleteReservation(requestId);

      if (!apiCallSuccessful) {
        //api call not successful, add request back to list
        developer.log("api call not successful");
        _requests.add(requestToDelete);
        notifyListeners();
        return;
      }

      db.deleteRequest(requestId);
      developer.log('deleted request');
    } catch (exception) {
      //add request to list, to allow clean removal from server
      _requests.add(requestToDelete);
      notifyListeners();
      developer.log(exception);
      throw exception;
    }
  }
}
