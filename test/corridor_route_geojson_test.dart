import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transpadang_live/features/tracking/data/corridor_route.dart';

String _feature(String corridor, String direction, List<List<double>> lngLat) {
  final coords = lngLat.map((p) => '[${p[0]},${p[1]}]').join(',');
  return '{"type":"Feature","properties":{"corridor":"$corridor",'
      '"direction":"$direction"},"geometry":{"type":"LineString",'
      '"coordinates":[$coords]}}';
}

String _collection(List<String> features) =>
    '{"type":"FeatureCollection","features":[${features.join(',')}]}';

void main() {
  test('membaca fitur LineString dan menukar [lng,lat] menjadi LatLng', () {
    final raw = _collection([
      _feature('K3', 'pulang', [
        [100.385995, -0.87503],
        [100.362989, -0.953263],
      ]),
      _feature('K3', 'pergi', [
        [100.362981, -0.953255],
        [100.386003, -0.874987],
      ]),
    ]);

    final parsed = parseCorridorRoutesGeoJson(raw);

    expect(parsed.keys, ['K3']);
    expect(parsed['K3']!.keys.toSet(), {'pergi', 'pulang'});
    expect(parsed['K3']!['pulang']!.first, const LatLng(-0.87503, 100.385995));
    expect(parsed['K3']!['pergi']!.last, const LatLng(-0.874987, 100.386003));
  });

  test('mengabaikan fitur tanpa properti corridor/direction', () {
    final raw = _collection([
      _feature('K3', 'pergi', [
        [100.36, -0.95],
        [100.37, -0.94],
      ]),
      '{"type":"Feature","properties":{},"geometry":{"type":"LineString",'
          '"coordinates":[[100.36,-0.95],[100.37,-0.94]]}}',
      '{"type":"Feature","properties":{"corridor":"K1"},"geometry":'
          '{"type":"LineString","coordinates":[[100.36,-0.95],[100.37,-0.94]]}}',
    ]);

    final parsed = parseCorridorRoutesGeoJson(raw);

    expect(parsed.keys, ['K3']);
    expect(parsed['K3']!.keys, ['pergi']);
  });

  test('mengabaikan geometri bukan LineString atau titik kurang dari dua', () {
    const raw = '{"type":"FeatureCollection","features":['
        '{"type":"Feature","properties":{"corridor":"K1","direction":"pergi"},'
        '"geometry":{"type":"Point","coordinates":[100.36,-0.95]}},'
        '{"type":"Feature","properties":{"corridor":"K2","direction":"pergi"},'
        '"geometry":{"type":"LineString","coordinates":[[100.36,-0.95]]}},'
        '{"type":"Feature","properties":{"corridor":"K4","direction":"pulang"},'
        '"geometry":{"type":"LineString","coordinates":[[100.36,-0.95],[100.37,-0.94]]}}'
        ']}';

    final parsed = parseCorridorRoutesGeoJson(raw);

    expect(parsed.keys, ['K4']);
  });

  test('JSON rusak atau bentuk tak dikenal menghasilkan peta kosong', () {
    expect(parseCorridorRoutesGeoJson(''), isEmpty);
    expect(parseCorridorRoutesGeoJson('{bukan json'), isEmpty);
    expect(parseCorridorRoutesGeoJson('{"type":"Feature"}'), isEmpty);
  });

  test('BOM di awal berkas (editor Windows) tetap terbaca', () {
    final raw = _collection([
      _feature('K1', 'pergi', [
        [100.36, -0.95],
        [100.37, -0.94],
      ]),
    ]);

    expect(parseCorridorRoutesGeoJson('\uFEFF$raw').keys, ['K1']);
  });

  test('aset manual nyata (assets/routes) memuat keenam koridor', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final dataset = await loadManualCorridorRouteDataset();

    for (final corridor in ['K1', 'K2', 'K3', 'K4', 'K5', 'K6']) {
      for (final direction in ['pergi', 'pulang']) {
        final points = dataset.points(corridor, direction);
        expect(points, isNotNull, reason: '$corridor/$direction');
        expect(points!.length, greaterThan(2), reason: '$corridor/$direction');
      }
    }
  });

  test('overlayRouteGeometry: manual menang, base mengisi arah yang kosong', () {
    const manual = CorridorRouteDataset({
      'K3': {
        'pergi': [LatLng(-0.95, 100.36), LatLng(-0.94, 100.37)],
      },
    });
    const generated = CorridorRouteDataset({
      'K3': {
        'pergi': [LatLng(-0.90, 100.30), LatLng(-0.91, 100.31)],
        'pulang': [LatLng(-0.87, 100.38), LatLng(-0.88, 100.39)],
      },
      'K1': {
        'pergi': [LatLng(-0.80, 100.31), LatLng(-0.81, 100.32)],
      },
    });

    final merged = overlayRouteGeometry(manual, generated);

    // Arah yang digambar manual menang.
    expect(merged.points('K3', 'pergi')!.first, const LatLng(-0.95, 100.36));
    // Arah lain tetap memakai hasil routing, begitu juga koridor lain.
    expect(merged.points('K3', 'pulang')!.first, const LatLng(-0.87, 100.38));
    expect(merged.points('K1', 'pergi'), hasLength(2));
    // Tanpa overlay, base dipakai apa adanya.
    expect(overlayRouteGeometry(null, generated).points('K3', 'pergi'),
        hasLength(2));
    expect(overlayRouteGeometry(manual, null).points('K3', 'pergi'),
        hasLength(2));
    expect(overlayRouteGeometry(null, null).corridors, isEmpty);
  });
}
