import 'package:apotek_santosa_farma_pos/services/supabase_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _validBackupPayload() => {
      'app': SupabaseService.expectedBackupAppId,
      'version': '1.0.0',
      'exported_at': '2026-11-27T13:00:00.000Z',
      'data': {
        'products': [
          {'id': 1, 'name': 'Paracetamol 500mg', 'price': 5000, 'stock': 20},
        ],
        'transactions': [
          {
            'id': 1,
            'invoice_no': 'POS-20261127-1001',
            'channel': 'toko',
            'payment_method': 'tunai',
            'status': 'selesai',
            'total': 5000,
          },
        ],
        'transaction_items': [
          {
            'id': 1,
            'transaction_id': 1,
            'product_name': 'Paracetamol 500mg',
            'qty': 1,
            'price': 5000,
            'subtotal': 5000,
          },
        ],
        'store_settings': [
          {'id': 1, 'is_open': true, 'online_orders_enabled': false},
        ],
        'customers': [
          {'id': 1, 'name': 'Paijo'},
        ],
      },
    };

void main() {
  test('validateBackupPayload accepts valid export payload', () {
    expect(
      () => SupabaseService.instance.validateBackupPayload(_validBackupPayload()),
      returnsNormally,
    );
  });

  test('validateBackupPayload rejects mismatched app identifier', () {
    final invalid = _validBackupPayload()..['app'] = 'Random App';
    expect(
      () => SupabaseService.instance.validateBackupPayload(invalid),
      throwsA(isA<FormatException>()),
    );
  });

  test('validateBackupPayload rejects missing required tables', () {
    final invalid = _validBackupPayload();
    (invalid['data'] as Map<String, dynamic>).remove('customers');
    expect(
      () => SupabaseService.instance.validateBackupPayload(invalid),
      throwsA(isA<FormatException>()),
    );
  });

  test('validateBackupPayload rejects row missing required column', () {
    final invalid = _validBackupPayload();
    final products = (invalid['data'] as Map<String, dynamic>)['products'] as List;
    (products.first as Map<String, dynamic>).remove('price');
    expect(
      () => SupabaseService.instance.validateBackupPayload(invalid),
      throwsA(isA<FormatException>()),
    );
  });
}
