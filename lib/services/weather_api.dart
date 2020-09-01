import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:freibad_app/services/api_keys.dart';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;

abstract class WeatherAPI {}

class WeatherAPIService extends WeatherAPI {
  static Future<List<Map<String, dynamic>>> fetchWeather(
    double requestLocationLat,
    double requestLocationLon,
  ) async {
    final List<Map<String, dynamic>> formattedWeatherResponse = [];
    final String url =
        'https://api.climacell.co/v3/weather/forecast/daily?lat=$requestLocationLat&lon=$requestLocationLon&' +
            'start_time=${DateTime.now().toIso8601String()}&' +
            'end_time=${DateTime.now().add(Duration(days: 14)).toIso8601String()}&' +
            'fields=weather_code&fields=temp';
    try {
      final weatherResponse = await http.get(
        url,
        headers: {
          'content-type': 'application/json',
          'apikey': APIKeys.ClimaCellAPIKey,
        },
      );
      developer.log(
          'request to the ClimaCell API finished, Statuscode: ${weatherResponse.statusCode}');
      if (weatherResponse.statusCode == 200) {
        List<dynamic> decodedResponse = jsonDecode(weatherResponse.body);

        for (Map<String, dynamic> dailyForecast in decodedResponse) {
          //get the max temp
          List<dynamic> listOfTemp = dailyForecast['temp'];
          Map<String, dynamic> dailyTempMaxInfo =
              listOfTemp[1]; //max temp is always second
          DateTime dailyTempMaxDateTime =
              DateTime.parse(dailyTempMaxInfo['observation_time']);
          double dailyTempMax = dailyTempMaxInfo['max']['value'].toDouble();

          //get weather code
          String dailyWeatherCode = dailyForecast['weather_code']['value'];

          formattedWeatherResponse.add(
            {
              'max_temp': dailyTempMax,
              'max_temp_time': dailyTempMaxDateTime.toIso8601String(),
              'weather_code': dailyWeatherCode
            },
          );
        }
      } else {
        debugPrint(weatherResponse.reasonPhrase);
        throw Exception(
            'Something went wrong calling the ClimaCell API, Error: ${weatherResponse.statusCode}');
      }
      developer.log('updated weather');
    } catch (exception) {
      developer.log('Error on calling the ClimaCell API', error: exception);
      throw exception;
    }
    return formattedWeatherResponse;
  }
}

class FakeWeatherAPIService extends WeatherAPI {
  static Future<List<Map<String, dynamic>>> fetchWeather(
    double requestLocationLat,
    double requestLocationLon,
  ) async {
    final List<Map<String, dynamic>> formattedWeatherResponse = [];
    for (int i = 0; i < 15; i++) {
      DateTime now = DateTime.now();
      formattedWeatherResponse.add(
        {
          'max_temp': 21,
          'max_temp_time': DateTime(now.year, now.month, now.day)
              .add(Duration(days: i))
              .toIso8601String(),
          'weather_code': 'partly_cloudy',
        },
      );
    }
    developer.log('updated fake weather');
    return Future.delayed(Duration(seconds: 5), () => formattedWeatherResponse);
  }
}