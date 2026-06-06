import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Test Supabase RLS and Status Updates', () async {
    await dotenv.load(fileName: ".env");
    final url = dotenv.get('SUPABASE_API_ENDPOINT').replaceAll('/rest/v1/', '');
    final serviceKey = dotenv.get('SUPABASE_SERVICE_ROLE_KEY');

    print('Supabase URL: $url');
    final serviceClient = SupabaseClient(url, serviceKey);

    final messages = await serviceClient
        .from('messages')
        .select()
        .limit(10);
    
    print('Sample Messages from database:');
    for (var m in messages) {
      print('ID: ${m['id']}, Sender: ${m['sender_id']}, Status: ${m['status']}, Conv: ${m['conversation_id']}');
    }
  });
}
