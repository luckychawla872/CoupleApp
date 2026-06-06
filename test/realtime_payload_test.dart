import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  test('Test Realtime Update Payload', () async {
    await dotenv.load();
    final supabaseUrl = dotenv.env['SUPABASE_API_ENDPOINT']!;
    final serviceRoleKey = dotenv.env['SUPABASE_SERVICE_ROLE_KEY']!;

    final url = supabaseUrl.replaceAll('/rest/v1/', '');

    await Supabase.initialize(
      url: url,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
    final client = Supabase.instance.client;

    print('Connected to Supabase. Setting up channel...');

    // We'll just fetch one conversation ID
    final res = await http.get(
      Uri.parse('${url}/rest/v1/conversations?select=id&limit=1'),
      headers: {
        'apikey': serviceRoleKey,
        'Authorization': 'Bearer $serviceRoleKey',
      },
    );
    final convs = jsonDecode(res.body);
    if (convs.isEmpty) {
      print('No conversations found.');
      return;
    }
    final convId = convs[0]['id'];

    // Setup realtime listener
    bool updateReceived = false;
    final channel = client.channel('test_channel');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        print('REALTIME EVENT: ${payload.eventType}');
        print('NEW RECORD: ${payload.newRecord}');
        print('OLD RECORD: ${payload.oldRecord}');
        if (payload.eventType == PostgresChangeEvent.update) {
          updateReceived = true;
        }
      },
    );
    await channel.subscribe();

    print('Channel subscribed. Fetching a message to update...');
    
    final msgRes = await http.get(
      Uri.parse('${url}/rest/v1/messages?conversation_id=eq.$convId&limit=1'),
      headers: {
        'apikey': serviceRoleKey,
        'Authorization': 'Bearer $serviceRoleKey',
      },
    );
    final msgs = jsonDecode(msgRes.body);
    if (msgs.isEmpty) {
      print('No messages found.');
      return;
    }
    final msgId = msgs[0]['id'];
    
    print('Updating message $msgId...');
    final updateRes = await http.patch(
      Uri.parse('${url}/rest/v1/messages?id=eq.$msgId'),
      headers: {
        'apikey': serviceRoleKey,
        'Authorization': 'Bearer $serviceRoleKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'status': 'delivered'}),
    );
    
    print('Update status: ${updateRes.statusCode}');
    
    // Wait for realtime event
    for (int i = 0; i < 10; i++) {
      if (updateReceived) break;
      await Future.delayed(const Duration(seconds: 1));
    }
    
    if (!updateReceived) {
      print('Timed out waiting for realtime event.');
    }
  });
}
