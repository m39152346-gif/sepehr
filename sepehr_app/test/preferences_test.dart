import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sepehr/core/app_settings.dart';
import 'package:sepehr/core/place.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    currentPlace.value = defaultPlace;
    appSettings.value = const AppSettings();
  });

  test('selected, recent, and favorite locations persist safely', () async {
    const frankfurt = Place(
      name: 'فرانکفورت',
      country: 'آلمان',
      lat: 50.1109,
      lon: 8.6821,
      timezone: 'Europe/Berlin',
      utcOffsetSeconds: 7200,
    );

    await setPlace(frankfurt);
    expect(currentPlace.value.name, 'فرانکفورت');
    expect((await loadRecentPlaces()).first.key, frankfurt.key);
    expect(await toggleFavoritePlace(frankfurt), isTrue);
    expect((await loadFavoritePlaces()).single.label, 'فرانکفورت، آلمان');
    expect(await toggleFavoritePlace(frankfurt), isFalse);
    expect(await loadFavoritePlaces(), isEmpty);
  });

  test('accessibility and display preferences persist', () async {
    await updateAppSettings(nightVision: true, fahrenheit: true, textScale: 1.25);
    appSettings.value = const AppSettings();
    await loadAppSettings();

    expect(appSettings.value.nightVision, isTrue);
    expect(appSettings.value.fahrenheit, isTrue);
    expect(appSettings.value.textScale, 1.25);
  });
}
