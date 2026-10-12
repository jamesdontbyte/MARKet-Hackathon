import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_final/models/business.dart';
import 'package:market_final/models/chat.dart';
import 'package:market_final/models/promo.dart';
import 'package:market_final/screens/shared/assistant_screen.dart';
import 'package:market_final/services/chat_service.dart';
import 'package:market_final/services/data_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fake DataService for testing assistant action confirmation
class FakeDataService extends Fake implements DataService {
  bool saveToStashCalled = false;
  String? savedUserId;
  String? savedPromoId;

  bool updatePromoCalled = false;
  Promo? updatedPromo;

  Promo? promoToReturn;
  Business? businessToReturn;

  @override
  Future<List<Business>> fetchVerifiedBusinesses({String? category}) async {
    return [
      Business(
        id: 'biz_1',
        name: 'Kape Tahanan',
        category: 'cafe',
        lat: 10.7431,
        lng: 121.9250,
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<Promo?> fetchPromoById(String promoId) async {
    return promoToReturn ??
        Promo(
          id: promoId,
          businessId: 'biz_1',
          title: '20% Off Coffee',
          startsAt: DateTime.now(),
          endsAt: DateTime.now().add(const Duration(days: 7)),
          createdAt: DateTime.now(),
        );
  }

  @override
  Future<Business?> fetchBusinessById(String businessId) async {
    return businessToReturn ??
        Business(
          id: businessId,
          name: 'Kape Tahanan',
          category: 'cafe',
          lat: 10.7431,
          lng: 121.9250,
          createdAt: DateTime.now(),
        );
  }

  @override
  Future<void> saveToStash(String userId, String promoId) async {
    saveToStashCalled = true;
    savedUserId = userId;
    savedPromoId = promoId;
  }

  @override
  Future<Promo> updatePromo(Promo promo) async {
    updatePromoCalled = true;
    updatedPromo = promo;
    return promo;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Draft Block Parser Tests', () {
    test('parses plain text without draft blocks', () {
      const input = 'Hello! Here are the best promos in San Jose today.';
      final segments = parseDraftBlocks(input);

      expect(segments.length, 1);
      expect(segments.first.isDraft, isFalse);
      expect(segments.first.text, input);
    });

    test('parses single draft block with surrounding text', () {
      const input = '''
Here is a recommended promo blurb:
:::draft
Enjoy 20% OFF our signature native coffee this weekend at Kape Tahanan!
:::
Let me know if you would like me to adjust the terms.
''';
      final segments = parseDraftBlocks(input);

      expect(segments.length, 3);
      expect(segments[0].isDraft, isFalse);
      expect(segments[0].text, 'Here is a recommended promo blurb:');
      expect(segments[1].isDraft, true);
      expect(segments[1].text,
          'Enjoy 20% OFF our signature native coffee this weekend at Kape Tahanan!');
      expect(segments[2].isDraft, false);
      expect(segments[2].text,
          'Let me know if you would like me to adjust the terms.');
    });

    test('parses multiple draft blocks in one response', () {
      const input = '''
Option A:
:::draft
Flash Sale: ₱50 OFF Lunch
:::
Option B:
:::draft
BOGO Free Iced Tea
:::
''';
      final segments = parseDraftBlocks(input);

      final drafts = segments.where((s) => s.isDraft).toList();
      expect(drafts.length, 2);
      expect(drafts[0].text, 'Flash Sale: ₱50 OFF Lunch');
      expect(drafts[1].text, 'BOGO Free Iced Tea');
    });
  });

  group('Sanitizer Unit Tests', () {
    test('removes asterisks, backticks, and markdown emphasis', () {
      const input = 'Here is **bold** text, *italic* text, and `inline code`.';
      final sanitized = sanitizeAssistantReply(input);
      expect(sanitized, isNot(contains('**')));
      expect(sanitized, isNot(contains('`')));
      expect(sanitized, 'Here is bold text, italic text, and inline code.');
    });

    test('removes UUIDs from reply text', () {
      const input = 'Check out promo d3b07384-d113-4e89-a5e2-63b71587a812 in San Jose!';
      final sanitized = sanitizeAssistantReply(input);
      expect(sanitized, isNot(contains('d3b07384-d113-4e89-a5e2-63b71587a812')));
      expect(sanitized, 'Check out promo  in San Jose!');
    });

    test('removes propose_save_to_stash(...) line and Propose Actions heading', () {
      const input = '''
Here are the best coffee deals for you in San Jose.

# Propose Actions:
propose_save_to_stash(promo_id="d3b07384-d113-4e89-a5e2-63b71587a812")

Would you like me to save this to your Stash?
''';
      final sanitized = sanitizeAssistantReply(input);
      expect(sanitized, isNot(contains('Propose Actions')));
      expect(sanitized, isNot(contains('propose_save_to_stash')));
      expect(sanitized, isNot(contains('d3b07384')));
      expect(sanitized, contains('Here are the best coffee deals for you in San Jose.'));
      expect(sanitized, contains('Would you like me to save this to your Stash?'));
    });

    test('keeps normal sentences and bullet lines, and converts * and - to •', () {
      const input = '''
Here are top picks:
* 20% off at Kape Tahanan
- Free iced tea refill
• Special native blend

Enjoy your visit!
''';
      final sanitized = sanitizeAssistantReply(input);
      expect(sanitized, contains('• 20% off at Kape Tahanan'));
      expect(sanitized, contains('• Free iced tea refill'));
      expect(sanitized, contains('• Special native blend'));
      expect(sanitized, contains('Here are top picks:'));
      expect(sanitized, contains('Enjoy your visit!'));
      expect(sanitized, isNot(contains('* 20%')));
      expect(sanitized, isNot(contains('- Free')));
    });

    test('leaves draft content copyable while removing markdown emphasis', () {
      const input = '''
Here is the announcement caption:
:::draft
**Big Weekend Sale!**
Enjoy `20% OFF` all iced lattes at Kape Tahanan.
:::
Let me know if you would like changes.
''';
      final sanitized = sanitizeAssistantReply(input);
      final segments = parseDraftBlocks(sanitized);

      final draftSeg = segments.firstWhere((s) => s.isDraft);
      expect(draftSeg.text, isNot(contains('**')));
      expect(draftSeg.text, isNot(contains('`')));
      expect(draftSeg.text, contains('Big Weekend Sale!'));
      expect(draftSeg.text, contains('Enjoy 20% OFF all iced lattes at Kape Tahanan.'));
    });
  });

  group('SuggestedPromo Model Tests', () {
    test('correctly serializes and deserializes SuggestedPromo', () {
      final json = {
        'id': 'promo_123',
        'title': 'BOGO Coffee',
        'business_name': 'Kape Tahanan',
        'value': 'BOGO',
        'distance': 'about 150 m away',
      };

      final promo = SuggestedPromo.fromJson(json);
      expect(promo.id, 'promo_123');
      expect(promo.title, 'BOGO Coffee');
      expect(promo.businessName, 'Kape Tahanan');
      expect(promo.value, 'BOGO');
      expect(promo.distance, 'about 150 m away');

      final serialized = promo.toJson();
      expect(serialized['id'], 'promo_123');
      expect(serialized['business_name'], 'Kape Tahanan');
    });
  });

  group('AssistantAction Model Tests', () {
    test('correctly serializes and deserializes tool proposal action', () {
      final json = {
        'name': 'propose_promo',
        'args': {
          'title': 'Weekend BOGO',
          'promo_type': 'bogo',
          'redeem_limit': 50,
        },
      };

      final action = AssistantAction.fromJson(json);
      expect(action.name, 'propose_promo');
      expect(action.args['title'], 'Weekend BOGO');
      expect(action.args['redeem_limit'], 50);

      final serialized = action.toJson();
      expect(serialized['name'], 'propose_promo');
      expect(serialized['args']['title'], 'Weekend BOGO');
    });
  });

  group('ChatService Unit Tests with Hand-Written Fakes', () {
    test('successful shopper response with action parsing', () async {
      final chatService = ChatService(
        invoker: (fn, {body, headers}) async {
          expect(fn, 'chat');
          expect(body!['messages'], isNotEmpty);

          return FunctionResponse(
            data: {
              'reply': 'I found a great promo for you!',
              'action': {
                'name': 'open_promo',
                'args': {'promo_id': 'promo_123'},
              },
            },
            status: 200,
          );
        },
      );

      final history = [
        ChatMessage(
          id: '1',
          role: ChatRole.user,
          content: 'Find coffee promos',
          timestamp: DateTime.now(),
        ),
      ];

      final response = await chatService.sendMessage(history: history);

      expect(response.role, ChatRole.assistant);
      expect(response.content, 'I found a great promo for you!');
      expect(response.isError, isFalse);
      expect(response.action, isNotNull);
      expect(response.action!.name, 'open_promo');
      expect(response.action!.args['promo_id'], 'promo_123');
    });

    test('handles HTTP 429 rate limit with friendly message', () async {
      final chatService = ChatService(
        invoker: (fn, {body, headers}) async {
          return FunctionResponse(
            data: {
              'error': 'Rate limit reached',
              'code': 'rate_limited',
            },
            status: 429,
          );
        },
      );

      final response = await chatService.sendMessage(
        history: [
          ChatMessage(
            id: '1',
            role: ChatRole.user,
            content: 'Hello',
            timestamp: DateTime.now(),
          ),
        ],
      );

      expect(response.isError, isTrue);
      expect(response.content, contains('20 requests per hour'));
    });

    test('handles FunctionException 429 with friendly message', () async {
      final chatService = ChatService(
        invoker: (fn, {body, headers}) async {
          throw FunctionException(
            status: 429,
            details: 'Too many requests',
            reasonPhrase: 'Too Many Requests',
          );
        },
      );

      final response = await chatService.sendMessage(
        history: [
          ChatMessage(
            id: '1',
            role: ChatRole.user,
            content: 'Hello',
            timestamp: DateTime.now(),
          ),
        ],
      );

      expect(response.isError, isTrue);
      expect(response.content, contains('20 requests per hour'));
    });

    test('maps SocketException to friendly connection error', () async {
      final chatService = ChatService(
        invoker: (fn, {body, headers}) async {
          throw const SocketException('No address associated with hostname');
        },
      );

      final response = await chatService.sendMessage(
        history: [
          ChatMessage(
            id: '1',
            role: ChatRole.user,
            content: 'Hello',
            timestamp: DateTime.now(),
          ),
        ],
      );

      expect(response.isError, isTrue);
      expect(response.content, contains('internet connection'));
    });
  });

  group('AssistantScreen Widget & Explicit Confirmation Tests', () {
    testWidgets('Shopper mode shows empty state with 3 shopper suggestions',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AssistantScreen(role: 'shopper'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Antique Shopper Assistant'), findsOneWidget);
      expect(find.text('Promos near me'), findsOneWidget);
      expect(find.text('How do I redeem a voucher?'), findsOneWidget);
      expect(find.text('Why am I not getting alerts?'), findsOneWidget);
      expect(find.textContaining('AI Assistant • Responses may be inaccurate'),
          findsOneWidget);
    });

    testWidgets('Merchant mode shows empty state with 3 merchant suggestions',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AssistantScreen(role: 'merchant'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MSME Store Assistant'), findsOneWidget);
      expect(find.text('Create a promo for me'), findsOneWidget);
      expect(find.text('Summarize my week'), findsOneWidget);
      expect(find.text('How does the Show QR work?'), findsOneWidget);
    });

    testWidgets('Action proposal DOES NOT execute automatically without user tap',
        (tester) async {
      final fakeData = FakeDataService();
      final chatService = ChatService(
        invoker: (fn, {body, headers}) async {
          return FunctionResponse(
            data: {
              'reply': 'Would you like to pause this promotion?',
              'action': {
                'name': 'pause_promo',
                'args': {'promo_id': 'promo_test_99'},
              },
            },
            status: 200,
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AssistantScreen(
            role: 'merchant',
            chatService: chatService,
            dataService: fakeData,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap suggestion to send a message
      await tester.tap(find.text('Create a promo for me'));
      await tester.pumpAndSettle();

      // Action card is displayed
      expect(find.text('Pause Promotion'), findsOneWidget);
      expect(find.text('Confirm Pause'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // CRITICAL ASSERTION: The action has NOT executed automatically
      expect(fakeData.updatePromoCalled, isFalse);

      // Now tap Cancel: Still must NOT execute
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(fakeData.updatePromoCalled, isFalse);
      expect(find.text('Action Cancelled'), findsOneWidget);
    });

    testWidgets('Action proposal executes only AFTER explicit user Confirm tap',
        (tester) async {
      final fakeData = FakeDataService();
      final chatService = ChatService(
        invoker: (fn, {body, headers}) async {
          return FunctionResponse(
            data: {
              'reply': 'I can pause this promotion for you.',
              'action': {
                'name': 'pause_promo',
                'args': {'promo_id': 'promo_test_99'},
              },
            },
            status: 200,
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AssistantScreen(
            role: 'merchant',
            chatService: chatService,
            dataService: fakeData,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create a promo for me'));
      await tester.pumpAndSettle();

      expect(fakeData.updatePromoCalled, isFalse);

      // Explicitly tap Confirm Pause
      await tester.tap(find.text('Confirm Pause'));
      await tester.pumpAndSettle();

      // Now it has executed
      expect(fakeData.updatePromoCalled, isTrue);
      expect(fakeData.updatedPromo?.active, isFalse);
      expect(find.text('Action Confirmed'), findsOneWidget);
    });

    testWidgets(
        'plain answer does not render Drafted Content card and renders SelectableText',
        (tester) async {
      final chatService = ChatService(
        invoker: (fn, {body, headers}) async {
          return FunctionResponse(
            data: {
              'reply':
                  'Kape Tahanan is located on Governor Villavert Street in San Jose.',
            },
            status: 200,
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AssistantScreen(
            role: 'shopper',
            chatService: chatService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Promos near me'));
      await tester.pumpAndSettle();

      // Normal answer rendered in chat bubble
      expect(
        find.text('Kape Tahanan is located on Governor Villavert Street in San Jose.'),
        findsOneWidget,
      );
      // NEVER renders Drafted Content card
      expect(find.text('Drafted Content'), findsNothing);
      expect(find.text('Copy'), findsNothing);
      // Renders SelectableText
      expect(find.byType(SelectableText), findsWidgets);
    });

    testWidgets('promo suggestion cards display details and show NO promo ids',
        (tester) async {
      final chatService = ChatService(
        invoker: (fn, {body, headers}) async {
          return FunctionResponse(
            data: {
              'reply': 'I found a great promo near you!',
              'suggested_promos': [
                {
                  'id': 'secret_promo_uuid_9999',
                  'title': 'Free Native Coffee',
                  'business_name': 'Kape Tahanan',
                  'value': 'FREE',
                  'distance': 'about 150 m away',
                },
              ],
            },
            status: 200,
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AssistantScreen(
            role: 'shopper',
            chatService: chatService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Promos near me'));
      await tester.pumpAndSettle();

      // Suggestion card displays business, title, value, distance
      expect(find.text('Kape Tahanan'), findsOneWidget);
      expect(find.text('Free Native Coffee'), findsOneWidget);
      expect(find.text('FREE'), findsOneWidget);
      expect(find.text('about 150 m away'), findsOneWidget);

      // CRITICAL: ID is strictly internal and never displayed
      expect(find.textContaining('secret_promo_uuid_9999'), findsNothing);
    });

    testWidgets(
        'action proposal confirm cards show friendly labels and NO IDs or function names',
        (tester) async {
      final chatService = ChatService(
        invoker: (fn, {body, headers}) async {
          return FunctionResponse(
            data: {
              'reply': 'Want me to save this to your Stash?',
              'action': {
                'name': 'propose_save_to_stash',
                'args': {
                  'promo_id': 'd3b07384-d113-4e89-a5e2-63b71587a812',
                  'title': 'Free Haircut',
                  'business_name': 'Biglang Gwapo',
                  'value_label': 'FREE',
                },
              },
            },
            status: 200,
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AssistantScreen(
            role: 'shopper',
            chatService: chatService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Promos near me'));
      await tester.pumpAndSettle();

      // Card shows friendly title matching user requirement
      expect(
        find.text('Save to Stash: Free Haircut at Biglang Gwapo'),
        findsOneWidget,
      );
      expect(find.text('Save to Stash'), findsWidgets);

      // NEVER shows UUID, ID or function name
      expect(find.textContaining('d3b07384'), findsNothing);
      expect(find.textContaining('propose_save_to_stash'), findsNothing);
      expect(find.textContaining('promo_id'), findsNothing);
    });
  });

  group('AssistantScreen Responsive Layout & Zero Overflow Tests', () {
    final testSizes = [
      const Size(360, 640),
      const Size(411, 891),
    ];
    final textScales = [1.0, 1.5];

    for (final size in testSizes) {
      for (final scale in textScales) {
        testWidgets(
            'AssistantScreen (Shopper) at ${size.width.toInt()}x${size.height.toInt()} scale $scale has no overflow',
            (tester) async {
          tester.view.physicalSize = Size(size.width * 2, size.height * 2);
          tester.view.devicePixelRatio = 2.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: const AssistantScreen(role: 'shopper'),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        });

        testWidgets(
            'AssistantScreen (Merchant) at ${size.width.toInt()}x${size.height.toInt()} scale $scale has no overflow',
            (tester) async {
          tester.view.physicalSize = Size(size.width * 2, size.height * 2);
          tester.view.devicePixelRatio = 2.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: const AssistantScreen(role: 'merchant'),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
