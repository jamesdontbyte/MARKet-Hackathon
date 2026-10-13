import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../models/business.dart';
import '../../models/chat.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/data_service.dart';
import '../../widgets/app_header.dart';
import '../merchant/catalog_screen.dart';
import '../shopper/promo_detail_screen.dart';
import '../shopper/storefront_screen.dart';

/// In-App AI Assistant Screen for Shoppers and MSME Merchants.
/// Fully conforms to Phase 11 specs:
/// - Agentic tool proposals requiring explicit user confirmation.
/// - In-memory conversation history.
/// - Draft text parsing with 1-tap Copy.
/// - Role-specific suggestion chips.
/// - Friendly error states with retry.
class AssistantScreen extends StatefulWidget {
  final String role; // 'shopper' or 'merchant'
  final ChatService? chatService;
  final DataService? dataService;
  final Business? business;

  const AssistantScreen({
    super.key,
    required this.role,
    this.chatService,
    this.dataService,
    this.business,
  });

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  late final ChatService _chatService;
  late final DataService _dataService;
  final AuthService _authService = AuthService();

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<ChatMessage> _messages = [];
  bool _isSending = false;
  String? _lastFailedPrompt;
  final Map<String, String> _actionStatuses = {}; // messageId -> 'confirmed' | 'cancelled'

  @override
  void initState() {
    super.initState();
    _chatService = widget.chatService ?? ChatService();
    _dataService = widget.dataService ?? DataService();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isMerchant => widget.role == 'merchant';

  List<String> get _suggestionChips {
    if (_isMerchant) {
      return const [
        'Create a promo for me',
        'Summarize my week',
        'How does the Show QR work?',
      ];
    } else {
      return const [
        'Promos near me',
        'How do I redeem a voucher?',
        'Why am I not getting alerts?',
      ];
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? textToSend]) async {
    final text = (textToSend ?? _inputController.text).trim();
    if (text.isEmpty || _isSending) return;

    _inputController.clear();
    _lastFailedPrompt = null;

    final userMessage = ChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      role: ChatRole.user,
      content: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isSending = true;
    });
    _scrollToBottom();

    Map<String, double>? distances;
    if (!_isMerchant && text.toLowerCase().contains('near me')) {
      try {
        final verifiedBizs = await _dataService.fetchVerifiedBusinesses();
        distances = await _chatService.computeBusinessDistances(verifiedBizs);
      } catch (_) {}
    }

    final response = await _chatService.sendMessage(
      history: _messages,
      distances: distances,
    );

    if (mounted) {
      setState(() {
        _messages.add(response);
        _isSending = false;
        if (response.isError) {
          _lastFailedPrompt = text;
        }
      });
      _scrollToBottom();
    }
  }

  void _retryLastMessage() {
    if (_lastFailedPrompt != null) {
      _sendMessage(_lastFailedPrompt);
    }
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _lastFailedPrompt = null;
      _actionStatuses.clear();
    });
  }

  Future<void> _handleActionConfirm(ChatMessage message) async {
    final action = message.action;
    if (action == null) return;

    setState(() {
      _actionStatuses[message.id] = 'processing';
    });

    try {
      if (action.name == 'propose_promo') {
        final args = action.args;
        DateTime startsAt;
        final rawStarts = args['starts_at']?.toString();
        if (rawStarts != null && rawStarts.isNotEmpty) {
          final parsed = DateTime.tryParse(rawStarts);
          startsAt = parsed != null ? parsed.toLocal() : DateTime.now();
        } else {
          startsAt = DateTime.now();
        }

        DateTime endsAt;
        final rawEnds = args['ends_at']?.toString();
        if (rawEnds != null && rawEnds.isNotEmpty) {
          final parsed = DateTime.tryParse(rawEnds);
          endsAt = parsed != null ? parsed.toLocal() : DateTime.now().add(const Duration(days: 7));
        } else {
          endsAt = DateTime.now().add(const Duration(days: 7));
        }

        final draft = PromoDraft(
          title: args['title']?.toString() ?? '',
          description: args['description']?.toString() ?? '',
          promoType: args['promo_type']?.toString() ?? 'percent',
          valueLabel: args['value_label']?.toString(),
          startsAt: startsAt,
          endsAt: endsAt,
          redeemLimit: (args['redeem_limit'] as num?)?.toInt() ?? 100,
        );

        if (mounted) {
          setState(() {
            _actionStatuses[message.id] = 'confirmed';
          });
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MerchantCatalogScreen(
                business: widget.business,
                initialTab: 1,
                initialPromoDraft: draft,
              ),
            ),
          );
        }
      } else if (action.name == 'propose_product') {
        final args = action.args;
        final draft = ProductDraft(
          name: args['name']?.toString() ?? '',
          price: (args['price'] as num?)?.toDouble() ?? 0.0,
          category: args['category']?.toString() ?? 'General',
          description: args['description']?.toString() ?? '',
        );

        if (mounted) {
          setState(() {
            _actionStatuses[message.id] = 'confirmed';
          });
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MerchantCatalogScreen(
                business: widget.business,
                initialTab: 0,
                initialProductDraft: draft,
              ),
            ),
          );
        }
      } else if (action.name == 'pause_promo') {
        final promoId = action.args['promo_id']?.toString() ?? '';
        final promo = await _dataService.fetchPromoById(promoId);
        if (promo != null) {
          await _dataService.updatePromo(promo.copyWith(active: false));
          if (mounted) {
            setState(() {
              _actionStatuses[message.id] = 'confirmed';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Promotion paused successfully.')),
            );
          }
        } else {
          throw Exception('Promotion could not be loaded.');
        }
      } else if (action.name == 'propose_save_to_stash') {
        final promoId = action.args['promo_id']?.toString() ?? '';
        final uid = _authService.currentUserId;
        if (uid != null) {
          await _dataService.saveToStash(uid, promoId);
          if (mounted) {
            setState(() {
              _actionStatuses[message.id] = 'confirmed';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Saved to your Stash!')),
            );
          }
        }
      } else if (action.name == 'open_promo') {
        final promoId = action.args['promo_id']?.toString() ?? '';
        if (mounted) {
          setState(() {
            _actionStatuses[message.id] = 'confirmed';
          });
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PromoDetailScreen(promoId: promoId),
            ),
          );
        }
      } else if (action.name == 'open_store') {
        final bizId = action.args['business_id']?.toString() ?? '';
        final biz = await _dataService.fetchBusinessById(bizId);
        if (biz != null && mounted) {
          setState(() {
            _actionStatuses[message.id] = 'confirmed';
          });
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StorefrontScreen(business: biz),
            ),
          );
        } else {
          throw Exception('Storefront could not be found.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _actionStatuses[message.id] = 'error';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
      }
    }
  }

  void _handleActionCancel(ChatMessage message) {
    setState(() {
      _actionStatuses[message.id] = 'cancelled';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketColors.surface,
      appBar: const AppHeader(
        subtitle: 'Assistant',
        showBack: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Disclaimer pill
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: MarketColors.surfaceContainerLow,
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 14, color: MarketColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'AI Assistant • Responses may be inaccurate.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: MarketColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (_messages.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: _clearChat,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.refresh_rounded, size: 14, color: MarketColors.primary),
                            SizedBox(width: 4),
                            Text(
                              'New chat',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: MarketColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Chat conversation view or Empty suggestions
            Expanded(
              child: _messages.isEmpty ? _buildEmptyState() : _buildMessageList(),
            ),

            // Typing indicator
            if (_isSending) _buildTypingIndicator(),

            // Error retry banner if last message failed
            if (_lastFailedPrompt != null && !_isSending) _buildRetryBar(),

            // Chat input bar
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: MarketColors.primaryContainer.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 28,
                color: MarketColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _isMerchant ? 'MSME Store Assistant' : 'Antique Shopper Assistant',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: MarketColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isMerchant
                ? 'Ask for promo copy, discount ideas, weekly funnel analysis, or counter setup.'
                : 'Discover promotions near you, get redemption help, or troubleshoot alerts.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: MarketColors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Suggestions to get started:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MarketColors.outline,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ..._suggestionChips.map(
              (chip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      side: const BorderSide(color: MarketColors.cardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: () => _sendMessage(chip),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_forward_rounded, size: 16, color: MarketColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            chip,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: MarketColors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageItem(message);
      },
    );
  }

  Widget _buildMessageItem(ChatMessage message) {
    final isUser = message.isUser;
    final status = _actionStatuses[message.id];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8, bottom: 4),
                  decoration: BoxDecoration(
                    color: MarketColors.primaryContainer.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: MarketColors.primary,
                  ),
                ),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? MarketColors.primaryContainer.withValues(alpha: 0.22)
                        : (message.isError
                            ? MarketColors.errorContainer.withValues(alpha: 0.3)
                            : MarketColors.surfaceContainerLowest),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: Border.all(
                      color: message.isError
                          ? MarketColors.error.withValues(alpha: 0.4)
                          : MarketColors.cardBorder,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...message.segments.map((segment) {
                        if (segment.isDraft) {
                          return _buildDraftCard(segment.text);
                        } else {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: SelectableText(
                              segment.text,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: message.isError
                                    ? MarketColors.error
                                    : MarketColors.onSurface,
                                height: 1.5,
                              ),
                            ),
                          );
                        }
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Promo Suggestions if present
          if (!isUser && message.suggestedPromos.isNotEmpty)
            _buildPromoSuggestionsList(message),

          // Action Proposal Card if present
          if (message.action != null) ...[
            const SizedBox(height: 8),
            _buildActionProposalCard(message, status),
          ],
        ],
      ),
    );
  }

  Widget _buildPromoSuggestionsList(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...message.suggestedPromos.map((promo) => _buildCompactPromoCard(promo)),
        ],
      ),
    );
  }

  Widget _buildCompactPromoCard(SuggestedPromo promo) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.85,
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PromoDetailScreen(promoId: promo.id),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MarketColors.cardBorder),
              boxShadow: MarketElevation.level1,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (promo.businessName.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.storefront_rounded,
                              size: 13,
                              color: MarketColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                promo.businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: MarketColors.primary,
                                ),
                              ),
                            ),
                            if (promo.distance != null && promo.distance!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                promo.distance!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: MarketColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        promo.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: MarketColors.onSurface,
                        ),
                      ),
                      if (promo.value.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: MarketColors.primaryContainer.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            promo.value,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: MarketColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: MarketColors.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraftCard(String draftText) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MarketColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, size: 16, color: MarketColors.primary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Drafted Content',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: MarketColors.primary,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: draftText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Draft copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.copy_rounded, size: 14, color: MarketColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: MarketColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            draftText,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: MarketColors.onSurface,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionProposalCard(ChatMessage message, String? status) {
    final action = message.action!;
    String title = 'Proposed Action';
    String description = '';
    String confirmLabel = 'Confirm';
    IconData icon = Icons.touch_app_rounded;

    if (action.name == 'propose_promo') {
      final pTitle = action.args['title']?.toString() ?? '';
      final pType = action.args['value_label']?.toString() ??
          action.args['promo_type']?.toString() ??
          '';
      title = pTitle.isNotEmpty
          ? 'Create Promo: $pTitle'
          : 'Create Promotion Draft';

      String dateText = '';
      final rawStarts = action.args['starts_at']?.toString();
      final rawEnds = action.args['ends_at']?.toString();
      if (rawStarts != null && rawStarts.isNotEmpty && rawEnds != null && rawEnds.isNotEmpty) {
        final s = DateTime.tryParse(rawStarts)?.toLocal();
        final e = DateTime.tryParse(rawEnds)?.toLocal();
        if (s != null && e != null) {
          dateText = ' • Valid: ${_formatProposalDate(s)} – ${_formatProposalDate(e)}';
        }
      }

      description = pType.isNotEmpty
          ? 'Type: $pType$dateText • Review and customize before publishing.'
          : (dateText.isNotEmpty
              ? 'Valid: $dateText • Review and customize before publishing.'
              : 'Review and customize your promotion draft before publishing.');
      confirmLabel = 'Review & Create Promo';
      icon = Icons.campaign_rounded;
    } else if (action.name == 'propose_product') {
      final pName = action.args['name']?.toString() ?? '';
      final price = action.args['price'];
      final category = action.args['category']?.toString() ?? 'General';
      title = pName.isNotEmpty
          ? 'Add Product: $pName'
          : 'Add Product to Catalog';
      description = price != null
          ? '₱$price ($category) • Review and add to your store catalog.'
          : 'Review and add this item to your store catalog.';
      confirmLabel = 'Review & Add Item';
      icon = Icons.add_box_rounded;
    } else if (action.name == 'pause_promo') {
      var promoTitle = action.args['title']?.toString() ??
          action.args['promo_title']?.toString() ??
          '';
      if (promoTitle.isEmpty) {
        final promoId = action.args['promo_id']?.toString() ?? '';
        final matched = message.suggestedPromos
            .where((p) => p.id == promoId)
            .firstOrNull;
        if (matched != null) promoTitle = matched.title;
      }

      title = promoTitle.isNotEmpty
          ? 'Pause Promotion: $promoTitle'
          : 'Pause Promotion';
      description =
          'Deactivate this promotion so shoppers can no longer claim it.';
      confirmLabel = 'Confirm Pause';
      icon = Icons.pause_circle_outline_rounded;
    } else if (action.name == 'propose_save_to_stash') {
      var promoTitle = action.args['title']?.toString() ??
          action.args['promo_title']?.toString() ??
          '';
      var businessName = action.args['business_name']?.toString() ?? '';
      var value = action.args['value_label']?.toString() ?? '';

      if (promoTitle.isEmpty) {
        final promoId = action.args['promo_id']?.toString() ?? '';
        final matched = message.suggestedPromos
            .where((p) => p.id == promoId)
            .firstOrNull;
        if (matched != null) {
          promoTitle = matched.title;
          businessName = matched.businessName;
          value = matched.value;
        }
      }

      if (promoTitle.isNotEmpty && businessName.isNotEmpty) {
        title = 'Save to Stash: $promoTitle at $businessName';
      } else if (promoTitle.isNotEmpty) {
        title = 'Save to Stash: $promoTitle';
      } else {
        title = 'Save Promotion to Stash';
      }

      description = value.isNotEmpty
          ? '$value • Save this voucher to your Stash for easy in-store redemption.'
          : 'Save this voucher to your Stash for easy in-store redemption.';
      confirmLabel = 'Save to Stash';
      icon = Icons.bookmark_add_rounded;
    } else if (action.name == 'open_promo') {
      var promoTitle = action.args['title']?.toString() ??
          action.args['promo_title']?.toString() ??
          '';
      var businessName = action.args['business_name']?.toString() ?? '';

      if (promoTitle.isEmpty) {
        final promoId = action.args['promo_id']?.toString() ?? '';
        final matched = message.suggestedPromos
            .where((p) => p.id == promoId)
            .firstOrNull;
        if (matched != null) {
          promoTitle = matched.title;
          businessName = matched.businessName;
        }
      }

      if (promoTitle.isNotEmpty && businessName.isNotEmpty) {
        title = 'View Promo: $promoTitle at $businessName';
      } else if (promoTitle.isNotEmpty) {
        title = 'View Promo: $promoTitle';
      } else {
        title = 'View Promotion Details';
      }
      description = 'Open full promotion terms, validity, and voucher info.';
      confirmLabel = 'Open Details';
      icon = Icons.open_in_new_rounded;
    } else if (action.name == 'open_store') {
      final businessName = action.args['business_name']?.toString() ??
          action.args['name']?.toString() ??
          '';
      title = businessName.isNotEmpty
          ? 'Visit Store: $businessName'
          : 'Visit Storefront Profile';
      description = 'Explore local store profile, products, and operating hours.';
      confirmLabel = 'View Store';
      icon = Icons.storefront_rounded;
    }

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.85,
      ),
      margin: const EdgeInsets.only(left: 36, top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MarketColors.primary.withValues(alpha: 0.3)),
        boxShadow: MarketElevation.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: MarketColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MarketColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                color: MarketColors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),

          if (status == 'confirmed') ...[
            Row(
              children: const [
                Icon(Icons.check_circle_rounded, size: 16, color: MarketColors.success),
                SizedBox(width: 6),
                Text(
                  'Action Confirmed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MarketColors.success,
                  ),
                ),
              ],
            ),
          ] else if (status == 'cancelled') ...[
            Row(
              children: const [
                Icon(Icons.cancel_rounded, size: 16, color: MarketColors.outline),
                SizedBox(width: 6),
                Text(
                  'Action Cancelled',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MarketColors.outline,
                  ),
                ),
              ],
            ),
          ] else ...[
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                TextButton(
                  onPressed: () => _handleActionCancel(message),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: MarketColors.outline,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MarketColors.primary,
                    foregroundColor: MarketColors.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: status == 'processing'
                      ? null
                      : () => _handleActionConfirm(message),
                  child: status == 'processing'
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: MarketColors.onPrimary,
                          ),
                        )
                      : Text(
                          confirmLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _formatProposalDate(DateTime dt) {
    final local = dt.toLocal();
    final m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ][local.month - 1];
    return '$m ${local.day}';
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: MarketColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MarketColors.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: MarketColors.primary,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Assistant is thinking...',
                  style: TextStyle(
                    fontSize: 12,
                    color: MarketColors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: MarketColors.errorContainer.withValues(alpha: 0.2),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: MarketColors.error),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Could not reach assistant.',
              style: TextStyle(fontSize: 12, color: MarketColors.error),
            ),
          ),
          TextButton(
            onPressed: _retryLastMessage,
            child: const Text(
              'Retry',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MarketColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        border: Border(
          top: BorderSide(color: MarketColors.cardBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: MarketColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: MarketColors.cardBorder),
              ),
              child: TextField(
                controller: _inputController,
                focusNode: _focusNode,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 13.5),
                decoration: const InputDecoration(
                  hintText: 'Ask about local promos, shops, or store tips...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: MarketColors.outline,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: MarketColors.primary,
              foregroundColor: MarketColors.onPrimary,
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
            onPressed: _isSending ? null : () => _sendMessage(),
          ),
        ],
      ),
    );
  }
}
