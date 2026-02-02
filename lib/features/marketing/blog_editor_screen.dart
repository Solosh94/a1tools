import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app_theme.dart';
import '../../config/api_config.dart';

class BlogEditorScreen extends StatefulWidget {
  final String username;
  final String role;

  const BlogEditorScreen({
    super.key,
    required this.username,
    required this.role,
  });

  @override
  State<BlogEditorScreen> createState() => _BlogEditorScreenState();
}

class _BlogEditorScreenState extends State<BlogEditorScreen>
    with SingleTickerProviderStateMixin {
  static const Color _accent = AppColors.accent;
  static const String _baseUrl = ApiConfig.apiBase;

  // Tab controller for Editor/History tabs
  late TabController _tabController;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _slugController = TextEditingController();
  final _excerptController = TextEditingController();

  // Rich text editor
  late QuillController _quillController;
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();

  // SEO fields
  final _seoTitleController = TextEditingController();
  final _seoDescriptionController = TextEditingController();
  final _focusKeyphraseController = TextEditingController();
  final _keyphrasesynonymsController = TextEditingController();
  final _canonicalUrlController = TextEditingController();

  // Related Keyphrases (up to 5 for Yoast Premium)
  final List<Map<String, TextEditingController>> _relatedKeyphrases = [];

  // Open Graph fields
  final _ogTitleController = TextEditingController();
  final _ogDescriptionController = TextEditingController();
  final _ogImageUrlController = TextEditingController();

  // Twitter Card fields
  final _twitterTitleController = TextEditingController();
  final _twitterDescriptionController = TextEditingController();
  final _twitterImageUrlController = TextEditingController();

  // Cornerstone content flag
  bool _isCornerstone = false;

  // SEO section expanded states
  bool _showAdvancedSeo = false;
  bool _showSocialSeo = false;

  // Category/Tag name input for group publishing
  final _categoryNamesController = TextEditingController();
  final _tagNamesController = TextEditingController();

  List<Map<String, dynamic>> _sites = [];
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _tags = [];
  List<Map<String, dynamic>> _authors = [];
  int? _selectedAuthorId;

  // Publishing mode: 'single' or 'group'
  String _publishMode = 'group';

  int? _selectedSiteId;
  int? _selectedGroupId;
  List<int> _selectedCategories = [];
  List<int> _selectedTags = [];

  bool _isLoadingSites = true;
  bool _isLoadingCategories = false;
  bool _isLoadingAuthors = false;
  bool _isPublishing = false;
  bool _isUploadingImage = false;

  int? _featuredMediaId;
  String? _featuredMediaUrl;

  // SEO Analysis state
  bool _showSeoAnalysis = true;
  List<Map<String, dynamic>> _seoProblems = [];
  List<Map<String, dynamic>> _seoImprovements = [];
  List<Map<String, dynamic>> _seoGood = [];

  // Related keyphrases SEO analysis (each keyphrase has its own analysis)
  List<Map<String, dynamic>> _relatedKeyphrasesAnalysis = [];

  // History state
  List<Map<String, dynamic>> _historyEntries = [];
  bool _isLoadingHistory = false;
  String _historySearchQuery = '';
  int _historyPage = 1;
  int _historyTotal = 0;

  // Edit mode state
  bool _isEditMode = false;
  String? _editingGroupPublishId;

  // Debounce timer for SEO analysis
  Timer? _seoDebounceTimer;

  // Word count for content
  int _wordCount = 0;
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _quillController = QuillController.basic();
    _loadSitesAndGroups();

    // Setup listeners for SEO analysis
    _titleController.addListener(_runSeoAnalysis);
    _seoTitleController.addListener(_runSeoAnalysis);
    _seoDescriptionController.addListener(_runSeoAnalysis);
    _focusKeyphraseController.addListener(_runSeoAnalysis);
    _quillController.addListener(_runSeoAnalysis);
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && _historyEntries.isEmpty) {
      _loadHistory();
    }
  }

  @override
  void dispose() {
    _seoDebounceTimer?.cancel();
    _tabController.dispose();
    _titleController.dispose();
    _slugController.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    _excerptController.dispose();
    _seoTitleController.dispose();
    _seoDescriptionController.dispose();
    _focusKeyphraseController.dispose();
    _keyphrasesynonymsController.dispose();
    _canonicalUrlController.dispose();
    _ogTitleController.dispose();
    _ogDescriptionController.dispose();
    _ogImageUrlController.dispose();
    _twitterTitleController.dispose();
    _twitterDescriptionController.dispose();
    _twitterImageUrlController.dispose();
    for (final rk in _relatedKeyphrases) {
      rk['keyphrase']?.dispose();
      rk['synonyms']?.dispose();
    }
    _categoryNamesController.dispose();
    _tagNamesController.dispose();
    super.dispose();
  }

  void _addRelatedKeyphrase() {
    if (_relatedKeyphrases.length >= 4) {
      _showError('Maximum 4 related keyphrases allowed (Focus keyphrase counts as 1)');
      return;
    }
    setState(() {
      _relatedKeyphrases.add({
        'keyphrase': TextEditingController(),
        'synonyms': TextEditingController(),
      });
    });
  }

  void _removeRelatedKeyphrase(int index) {
    setState(() {
      _relatedKeyphrases[index]['keyphrase']?.dispose();
      _relatedKeyphrases[index]['synonyms']?.dispose();
      _relatedKeyphrases.removeAt(index);
    });
  }

  Future<void> _loadSitesAndGroups() async {
    try {
      final results = await Future.wait([
        http.get(Uri.parse('$_baseUrl/wordpress_publish.php?action=sites')),
        http.get(Uri.parse('$_baseUrl/wordpress_publish.php?action=groups')),
      ]);

      final sitesData = jsonDecode(results[0].body);
      final groupsData = jsonDecode(results[1].body);

      setState(() {
        if (sitesData['success'] == true) {
          _sites = List<Map<String, dynamic>>.from(sitesData['sites'] ?? []);
        }
        if (groupsData['success'] == true) {
          _groups = List<Map<String, dynamic>>.from(groupsData['groups'] ?? []);
        }
        _isLoadingSites = false;
      });
    } catch (e) {
      setState(() => _isLoadingSites = false);
      _showError('Failed to load sites: $e');
    }
  }

  Future<void> _loadCategoriesAndTags(int siteId) async {
    setState(() {
      _isLoadingCategories = true;
      _categories = [];
      _tags = [];
      _selectedCategories = [];
      _selectedTags = [];
    });

    try {
      final results = await Future.wait([
        http.get(Uri.parse('$_baseUrl/wordpress_publish.php?action=categories&site_id=$siteId')),
        http.get(Uri.parse('$_baseUrl/wordpress_publish.php?action=tags&site_id=$siteId')),
      ]);

      final catData = jsonDecode(results[0].body);
      final tagData = jsonDecode(results[1].body);

      setState(() {
        if (catData['success'] == true) {
          _categories = List<Map<String, dynamic>>.from(catData['categories'] ?? []);
        }
        if (tagData['success'] == true) {
          _tags = List<Map<String, dynamic>>.from(tagData['tags'] ?? []);
        }
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() => _isLoadingCategories = false);
      _showError('Failed to load categories/tags: $e');
    }
  }

  Future<void> _loadAuthors(int siteId) async {
    setState(() {
      _isLoadingAuthors = true;
      _authors = [];
      _selectedAuthorId = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/wordpress_publish.php?action=authors&site_id=$siteId'),
      );

      final data = jsonDecode(response.body);

      setState(() {
        if (data['success'] == true) {
          _authors = List<Map<String, dynamic>>.from(data['authors'] ?? []);
          // Try to find "Single Post" author as default
          final singlePostAuthor = _authors.firstWhere(
            (a) => a['name'].toString().toLowerCase() == 'single post',
            orElse: () => _authors.isNotEmpty ? _authors.first : {},
          );
          if (singlePostAuthor.isNotEmpty) {
            _selectedAuthorId = singlePostAuthor['id'];
          }
        }
        _isLoadingAuthors = false;
      });
    } catch (e) {
      setState(() => _isLoadingAuthors = false);
      _showError('Failed to load authors: $e');
    }
  }

  Future<void> _uploadFeaturedImage() async {
    if (_publishMode == 'single' && _selectedSiteId == null) {
      _showError('Please select a WordPress site first');
      return;
    }

    // For group publishing, we need at least one site in the group to upload to
    int? uploadSiteId = _selectedSiteId;
    if (_publishMode == 'group' && _selectedGroupId != null) {
      final group = _groups.firstWhere((g) => g['id'] == _selectedGroupId, orElse: () => {});
      final sites = group['sites'] as List? ?? [];
      if (sites.isNotEmpty) {
        uploadSiteId = sites.first['id'];
      }
    }

    if (uploadSiteId == null) {
      _showError('Please select a group or site first');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/wordpress_publish.php?action=upload_media'),
      );

      request.fields['site_id'] = uploadSiteId.toString();
      request.files.add(await http.MultipartFile.fromPath('file', file.path!));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        setState(() {
          _featuredMediaId = data['media']['id'];
          _featuredMediaUrl = data['media']['url'];
        });
        _showSuccess('Image uploaded successfully');
      } else {
        _showError(data['error'] ?? 'Upload failed');
      }
    } catch (e) {
      _showError('Upload error: $e');
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _publish({bool asDraft = false}) async {
    if (!_formKey.currentState!.validate()) return;

    // Validate content from Quill editor
    final plainText = _getPlainText().trim();
    if (plainText.isEmpty) {
      _showError('Content is required');
      return;
    }

    if (_publishMode == 'single' && _selectedSiteId == null) {
      _showError('Please select a WordPress site');
      return;
    }

    if (_publishMode == 'group' && _selectedGroupId == null) {
      _showError('Please select a group');
      return;
    }

    setState(() => _isPublishing = true);

    try {
      if (_isEditMode && _editingGroupPublishId != null) {
        // Update existing post(s)
        if (_publishMode == 'single') {
          await _updateSinglePost();
        } else {
          await _updateGroupPosts();
        }
      } else {
        // Create new post(s)
        if (_publishMode == 'single') {
          await _publishToSingleSite(asDraft);
        } else {
          await _publishToGroup(asDraft);
        }
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isPublishing = false);
    }
  }

  Future<void> _updateSinglePost() async {
    final seoData = _buildSeoData();

    final response = await http.post(
      Uri.parse('$_baseUrl/wordpress_publish.php?action=update_post'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'group_publish_id': _editingGroupPublishId,
        'title': _titleController.text.trim(),
        'content': _deltaToHtml(),
        'excerpt': _excerptController.text.trim(),
        'categories': _selectedCategories,
        'tags': _selectedTags,
        ...seoData,
      }),
    );

    final data = jsonDecode(response.body);

    if (data['success'] == true) {
      _showSuccessDialog(
        title: 'Updated!',
        message: data['message'],
        results: [
          {
            'success': true,
            'site_name': 'Post',
            'link': data['post']?['link'] ?? '',
          }
        ],
      );
      _clearEditMode();
      _loadHistory(refresh: true);
    } else {
      _showError(data['error'] ?? 'Failed to update post');
    }
  }

  Future<void> _updateGroupPosts() async {
    // Parse category and tag names
    final categoryNames = _categoryNamesController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final tagNames = _tagNamesController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final seoData = _buildSeoData();

    final response = await http.post(
      Uri.parse('$_baseUrl/wordpress_publish.php?action=update_group'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'group_publish_id': _editingGroupPublishId,
        'title': _titleController.text.trim(),
        'content': _deltaToHtml(),
        'excerpt': _excerptController.text.trim(),
        'category_names': categoryNames,
        'tag_names': tagNames,
        ...seoData,
      }),
    );

    final data = jsonDecode(response.body);

    if (data['success'] == true) {
      _showSuccessDialog(
        title: 'Updated!',
        message: data['message'],
        results: List<Map<String, dynamic>>.from(data['results'] ?? []),
      );
      _clearEditMode();
      _loadHistory(refresh: true);
    } else {
      _showError(data['error'] ?? 'Failed to update posts');
    }
  }

  /// Convert Quill Delta to HTML for WordPress
  /// This properly handles all block and inline formatting
  String _deltaToHtml() {
    final delta = _quillController.document.toDelta();
    final ops = delta.toList();
    final htmlBuffer = StringBuffer();

    // Track current line content and block attributes
    final lineBuffer = StringBuffer();
    String? currentListType;
    bool inList = false;

    for (int i = 0; i < ops.length; i++) {
      final op = ops[i];

      if (op.data is Map) {
        // Handle embeds (images, videos, etc.)
        final data = op.data as Map;
        if (data.containsKey('image')) {
          lineBuffer.write('<img src="${_escapeHtml(data['image'].toString())}" />');
        }
        continue;
      }

      if (op.data is! String) continue;

      final text = op.data as String;
      final attrs = op.attributes ?? {};

      // Split text by newlines to handle block formatting
      final segments = text.split('\n');

      for (int j = 0; j < segments.length; j++) {
        final segment = segments[j];

        if (segment.isNotEmpty) {
          // Apply inline formatting to this segment
          String formattedText = _escapeHtml(segment);

          if (attrs.containsKey('link')) {
            final link = _escapeHtml(attrs['link'].toString());
            formattedText = '<a href="$link">$formattedText</a>';
          }
          if (attrs.containsKey('bold')) {
            formattedText = '<strong>$formattedText</strong>';
          }
          if (attrs.containsKey('italic')) {
            formattedText = '<em>$formattedText</em>';
          }
          if (attrs.containsKey('underline')) {
            formattedText = '<u>$formattedText</u>';
          }
          if (attrs.containsKey('strike')) {
            formattedText = '<s>$formattedText</s>';
          }

          lineBuffer.write(formattedText);
        }

        // Handle newline - check if this line has block formatting
        if (j < segments.length - 1) {
          // This is a newline within this operation
          final lineContent = lineBuffer.toString();
          lineBuffer.clear();

          // Check block attributes on the newline character
          Map<String, dynamic>? blockAttrs;

          // In Quill, block attributes are on the newline operation
          // If this op has block attributes and we're at a newline, use them
          if (attrs.containsKey('header') ||
              attrs.containsKey('list') ||
              attrs.containsKey('blockquote') ||
              attrs.containsKey('align')) {
            blockAttrs = attrs;
          }

          _writeBlockLine(htmlBuffer, lineContent, blockAttrs, currentListType, (newListType) {
            if (inList && currentListType != newListType) {
              // Close previous list
              htmlBuffer.write(currentListType == 'ordered' ? '</ol>\n' : '</ul>\n');
              inList = false;
            }
            if (newListType != null && !inList) {
              // Open new list
              htmlBuffer.write(newListType == 'ordered' ? '<ol>\n' : '<ul>\n');
              inList = true;
            }
            currentListType = newListType;
          });
        }
      }
    }

    // Handle any remaining content in the line buffer
    final remaining = lineBuffer.toString();
    if (remaining.isNotEmpty) {
      _writeBlockLine(htmlBuffer, remaining, null, currentListType, (newListType) {
        if (inList && currentListType != newListType) {
          htmlBuffer.write(currentListType == 'ordered' ? '</ol>\n' : '</ul>\n');
          inList = false;
        }
        currentListType = newListType;
      });
    }

    // Close any open list
    if (inList) {
      htmlBuffer.write(currentListType == 'ordered' ? '</ol>\n' : '</ul>\n');
    }

    return htmlBuffer.toString().trim();
  }

  /// Write a line with appropriate block-level HTML tags
  void _writeBlockLine(
    StringBuffer buffer,
    String content,
    Map<String, dynamic>? attrs,
    String? currentListType,
    void Function(String?) onListChange,
  ) {
    if (content.isEmpty && (attrs == null || !attrs.containsKey('list'))) {
      // Empty line without list - just skip or add break
      return;
    }

    if (attrs != null) {
      // Check for header
      if (attrs.containsKey('header')) {
        final level = attrs['header'];
        onListChange(null); // Close any open list
        buffer.write('<h$level>$content</h$level>\n');
        return;
      }

      // Check for blockquote
      if (attrs.containsKey('blockquote')) {
        onListChange(null); // Close any open list
        buffer.write('<blockquote>$content</blockquote>\n');
        return;
      }

      // Check for list
      if (attrs.containsKey('list')) {
        final listType = attrs['list'] == 'ordered' ? 'ordered' : 'bullet';
        onListChange(listType);
        buffer.write('<li>$content</li>\n');
        return;
      }

      // Check for alignment
      if (attrs.containsKey('align')) {
        final align = attrs['align'];
        onListChange(null); // Close any open list
        buffer.write('<p style="text-align: $align;">$content</p>\n');
        return;
      }
    }

    // Default: wrap in paragraph
    onListChange(null); // Close any open list
    if (content.isNotEmpty) {
      buffer.write('<p>$content</p>\n');
    }
  }

  /// Escape HTML special characters
  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Get plain text content for SEO analysis
  String _getPlainText() {
    return _quillController.document.toPlainText();
  }

  /// Run SEO analysis with debouncing to improve performance
  void _runSeoAnalysis() {
    _seoDebounceTimer?.cancel();
    _seoDebounceTimer = Timer(const Duration(milliseconds: 300), _performSeoAnalysis);
  }

  /// Perform the actual SEO analysis (Yoast-style checks)
  void _performSeoAnalysis() {
    if (!mounted) return;

    final title = _titleController.text.trim();
    final seoTitle = _seoTitleController.text.trim();
    final metaDesc = _seoDescriptionController.text.trim();
    final keyphrase = _focusKeyphraseController.text.trim().toLowerCase();
    final keyphraseSynonyms = _keyphrasesynonymsController.text.trim().toLowerCase();
    final content = _getPlainText().toLowerCase();
    final htmlContent = _deltaToHtml().toLowerCase();

    // Update word/character count
    _updateWordCount();

    final List<Map<String, dynamic>> problems = [];
    final List<Map<String, dynamic>> improvements = [];
    final List<Map<String, dynamic>> good = [];

    // Helper function to check if keyphrase or its synonyms appear in text
    bool containsKeyphraseOrSynonyms(String text, String kp, String synonyms) {
      if (text.contains(kp)) return true;
      if (synonyms.isNotEmpty) {
        final synonymList = synonyms.split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty);
        for (final syn in synonymList) {
          if (text.contains(syn)) return true;
        }
      }
      return false;
    }

    // Helper function to count keyphrase occurrences (including synonyms)
    int countKeyphraseOccurrences(String text, String kp, String synonyms) {
      int count = RegExp(RegExp.escape(kp)).allMatches(text).length;
      if (synonyms.isNotEmpty) {
        final synonymList = synonyms.split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty);
        for (final syn in synonymList) {
          count += RegExp(RegExp.escape(syn)).allMatches(text).length;
        }
      }
      return count;
    }

    // Check Focus Keyphrase
    if (keyphrase.isEmpty) {
      problems.add({
        'message': 'No focus keyphrase set',
        'detail': 'Set a focus keyphrase to optimize your content for search engines.',
      });
    } else {
      // Check keyphrase in title
      final effectiveTitle = seoTitle.isNotEmpty ? seoTitle.toLowerCase() : title.toLowerCase();
      if (containsKeyphraseOrSynonyms(effectiveTitle, keyphrase, keyphraseSynonyms)) {
        good.add({
          'message': 'Keyphrase in title',
          'detail': 'The focus keyphrase appears in the title.',
        });
      } else {
        problems.add({
          'message': 'Keyphrase missing in title',
          'detail': 'The focus keyphrase does not appear in the title.',
        });
      }

      // Check keyphrase in first paragraph (first 300 chars)
      final intro = content.substring(0, content.length > 300 ? 300 : content.length);
      if (containsKeyphraseOrSynonyms(intro, keyphrase, keyphraseSynonyms)) {
        good.add({
          'message': 'Keyphrase in introduction',
          'detail': 'The focus keyphrase appears in the first paragraph.',
        });
      } else {
        problems.add({
          'message': 'Keyphrase not in introduction',
          'detail': 'Your keyphrase or its synonyms do not appear in the first paragraph. Make sure the topic is clear immediately.',
        });
      }

      // Check keyphrase density (0.5% - 3%)
      final keyphraseCount = countKeyphraseOccurrences(content, keyphrase, keyphraseSynonyms);
      final wordCount = content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      if (wordCount > 0) {
        final density = (keyphraseCount / wordCount) * 100;
        if (density < 0.5) {
          problems.add({
            'message': 'Keyphrase density is low ($keyphraseCount times)',
            'detail': 'The keyphrase was found $keyphraseCount time${keyphraseCount == 1 ? '' : 's'}. That\'s less than the recommended minimum of 3 times for a text of this length. Focus on your keyphrase!',
          });
        } else if (density > 3) {
          problems.add({
            'message': 'Keyphrase density is too high (${density.toStringAsFixed(1)}%)',
            'detail': 'Reduce the use of the focus keyphrase to avoid over-optimization.',
          });
        } else {
          good.add({
            'message': 'Keyphrase density is optimal (${density.toStringAsFixed(1)}%)',
            'detail': 'The focus keyphrase appears at a good frequency.',
          });
        }
      }

      // Check keyphrase in meta description
      if (metaDesc.isNotEmpty && containsKeyphraseOrSynonyms(metaDesc.toLowerCase(), keyphrase, keyphraseSynonyms)) {
        good.add({
          'message': 'Keyphrase in meta description',
          'detail': 'Keyphrase or synonym appear in the meta description.',
        });
      } else if (metaDesc.isNotEmpty) {
        problems.add({
          'message': 'Keyphrase not in meta description',
          'detail': 'The meta description has been specified, but it does not contain the keyphrase. Fix that!',
        });
      }

      // Check keyphrase in image alt attributes
      final imgAltRegex = RegExp('<img[^>]*alt=["\']([^"\']*)["\'][^>]*>', caseSensitive: false);
      final altMatches = imgAltRegex.allMatches(htmlContent);
      bool keyphraseInAlt = false;
      int imageCount = 0;
      for (final match in altMatches) {
        imageCount++;
        final altText = match.group(1)?.toLowerCase() ?? '';
        if (containsKeyphraseOrSynonyms(altText, keyphrase, keyphraseSynonyms)) {
          keyphraseInAlt = true;
          break;
        }
      }
      if (imageCount == 0) {
        problems.add({
          'message': 'Keyphrase in image alt attributes',
          'detail': 'This page does not have images, a keyphrase, or both. Add some images with alt attributes that include the keyphrase or synonyms!',
        });
      } else if (!keyphraseInAlt) {
        problems.add({
          'message': 'Keyphrase in image alt attributes',
          'detail': 'Images on this page do not have alt attributes that contain the keyphrase. Add the keyphrase to at least one image alt attribute.',
        });
      } else {
        good.add({
          'message': 'Keyphrase in image alt attributes',
          'detail': 'The keyphrase appears in at least one image alt attribute.',
        });
      }
    }

    // Check Meta Description length (120-160 chars optimal)
    if (metaDesc.isEmpty) {
      problems.add({
        'message': 'No meta description',
        'detail': 'Write a meta description to tell search engines what your page is about.',
      });
    } else if (metaDesc.length < 120) {
      improvements.add({
        'message': 'Meta description too short (${metaDesc.length} chars)',
        'detail': 'Your meta description should be 120-160 characters for best results.',
      });
    } else if (metaDesc.length > 160) {
      improvements.add({
        'message': 'Meta description too long (${metaDesc.length} chars)',
        'detail': 'Your meta description may be truncated. Keep it under 160 characters.',
      });
    } else {
      good.add({
        'message': 'Meta description length is good (${metaDesc.length} chars)',
        'detail': 'Your meta description is an optimal length.',
      });
    }

    // Check Title length (50-60 chars optimal)
    final effectiveTitle = seoTitle.isNotEmpty ? seoTitle : title;
    if (effectiveTitle.isEmpty) {
      problems.add({
        'message': 'No title set',
        'detail': 'Add a title for your post.',
      });
    } else if (effectiveTitle.length < 30) {
      improvements.add({
        'message': 'Title too short (${effectiveTitle.length} chars)',
        'detail': 'Your title should be 50-60 characters for best SEO results.',
      });
    } else if (effectiveTitle.length > 60) {
      improvements.add({
        'message': 'Title may be too long (${effectiveTitle.length} chars)',
        'detail': 'Your title may be truncated in search results. Aim for 50-60 characters.',
      });
    } else {
      good.add({
        'message': 'Title length is good (${effectiveTitle.length} chars)',
        'detail': 'Your title is an optimal length for search engines.',
      });
    }

    // Check content length (300+ words recommended)
    final wordCount = content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (wordCount < 100) {
      problems.add({
        'message': 'Content is too short ($wordCount words)',
        'detail': 'Write at least 300 words for better SEO performance.',
      });
    } else if (wordCount < 300) {
      improvements.add({
        'message': 'Content could be longer ($wordCount words)',
        'detail': 'Consider expanding your content to 300+ words for better rankings.',
      });
    } else {
      good.add({
        'message': 'Content length is good ($wordCount words)',
        'detail': 'Your content has enough words for SEO.',
      });
    }

    // Analyze each related keyphrase separately (like Yoast Premium)
    final List<Map<String, dynamic>> relatedAnalysis = [];
    for (int i = 0; i < _relatedKeyphrases.length; i++) {
      final rk = _relatedKeyphrases[i];
      final relatedKp = rk['keyphrase']!.text.trim().toLowerCase();
      final relatedSynonyms = rk['synonyms']!.text.trim().toLowerCase();

      if (relatedKp.isEmpty) continue;

      final List<Map<String, dynamic>> rkProblems = [];
      final List<Map<String, dynamic>> rkGood = [];

      // Check related keyphrase in introduction
      final intro = content.substring(0, content.length > 300 ? 300 : content.length);
      if (containsKeyphraseOrSynonyms(intro, relatedKp, relatedSynonyms)) {
        rkGood.add({
          'message': 'Keyphrase in introduction',
          'detail': 'The keyphrase or its synonyms appear in the first paragraph.',
        });
      } else {
        rkProblems.add({
          'message': 'Keyphrase in introduction',
          'detail': 'Your keyphrase or its synonyms do not appear in the first paragraph. Make sure the topic is clear immediately.',
        });
      }

      // Check related keyphrase density
      final rkCount = countKeyphraseOccurrences(content, relatedKp, relatedSynonyms);
      if (wordCount > 0) {
        final rkDensity = (rkCount / wordCount) * 100;
        if (rkCount < 3) {
          rkProblems.add({
            'message': 'Keyphrase density',
            'detail': 'The keyphrase was found $rkCount time${rkCount == 1 ? '' : 's'}. That\'s less than the recommended minimum of 3 times for a text of this length. Focus on your keyphrase!',
          });
        } else if (rkDensity > 3) {
          rkProblems.add({
            'message': 'Keyphrase density',
            'detail': 'The keyphrase density is too high (${rkDensity.toStringAsFixed(1)}%). Reduce usage to avoid over-optimization.',
          });
        } else {
          rkGood.add({
            'message': 'Keyphrase density',
            'detail': 'The keyphrase appears at a good frequency ($rkCount times).',
          });
        }
      }

      // Check related keyphrase in meta description
      if (metaDesc.isNotEmpty && containsKeyphraseOrSynonyms(metaDesc.toLowerCase(), relatedKp, relatedSynonyms)) {
        rkGood.add({
          'message': 'Keyphrase in meta description',
          'detail': 'Keyphrase or synonym appear in the meta description.',
        });
      } else if (metaDesc.isNotEmpty) {
        rkProblems.add({
          'message': 'Keyphrase in meta description',
          'detail': 'The meta description has been specified, but it does not contain the keyphrase. Fix that!',
        });
      }

      // Check related keyphrase in image alt attributes
      final imgAltRegex = RegExp('<img[^>]*alt=["\']([^"\']*)["\'][^>]*>', caseSensitive: false);
      final altMatches = imgAltRegex.allMatches(htmlContent);
      bool rkInAlt = false;
      int imgCount = 0;
      for (final match in altMatches) {
        imgCount++;
        final altText = match.group(1)?.toLowerCase() ?? '';
        if (containsKeyphraseOrSynonyms(altText, relatedKp, relatedSynonyms)) {
          rkInAlt = true;
          break;
        }
      }
      if (imgCount == 0) {
        rkProblems.add({
          'message': 'Keyphrase in image alt attributes',
          'detail': 'This page does not have images, a keyphrase, or both. Add some images with alt attributes that include the keyphrase or synonyms!',
        });
      } else if (!rkInAlt) {
        rkProblems.add({
          'message': 'Keyphrase in image alt attributes',
          'detail': 'Images on this page do not have alt attributes that contain the keyphrase.',
        });
      } else {
        rkGood.add({
          'message': 'Keyphrase in image alt attributes',
          'detail': 'The keyphrase appears in at least one image alt attribute.',
        });
      }

      // Keyphrase length check
      final rkWords = relatedKp.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      if (rkWords <= 4) {
        rkGood.add({
          'message': 'Keyphrase length',
          'detail': 'Good job!',
        });
      } else {
        rkProblems.add({
          'message': 'Keyphrase length',
          'detail': 'The keyphrase is $rkWords words long. Consider using a shorter keyphrase.',
        });
      }

      relatedAnalysis.add({
        'keyphrase': rk['keyphrase']!.text.trim(),
        'synonyms': rk['synonyms']!.text.trim(),
        'problems': rkProblems,
        'good': rkGood,
        'expanded': false,
      });
    }

    setState(() {
      _seoProblems = problems;
      _seoImprovements = improvements;
      _seoGood = good;
      _relatedKeyphrasesAnalysis = relatedAnalysis;
    });
  }

  Map<String, dynamic> _buildSeoData() {
    // Build related keyphrases array
    final relatedKeyphrasesData = _relatedKeyphrases
        .where((rk) => rk['keyphrase']!.text.trim().isNotEmpty)
        .map((rk) => {
              'keyphrase': rk['keyphrase']!.text.trim(),
              'synonyms': rk['synonyms']!.text.trim(),
            })
        .toList();

    return {
      // Slug
      'slug': _slugController.text.trim(),
      // Core SEO
      'seo_title': _seoTitleController.text.trim(),
      'seo_description': _seoDescriptionController.text.trim(),
      'focus_keyphrase': _focusKeyphraseController.text.trim(),
      'keyphrase_synonyms': _keyphrasesynonymsController.text.trim(),
      'related_keyphrases': relatedKeyphrasesData,
      'canonical_url': _canonicalUrlController.text.trim(),
      'is_cornerstone': _isCornerstone,
      // Open Graph
      'og_title': _ogTitleController.text.trim(),
      'og_description': _ogDescriptionController.text.trim(),
      'og_image': _ogImageUrlController.text.trim(),
      // Twitter
      'twitter_title': _twitterTitleController.text.trim(),
      'twitter_description': _twitterDescriptionController.text.trim(),
      'twitter_image': _twitterImageUrlController.text.trim(),
    };
  }

  Future<void> _publishToSingleSite(bool asDraft) async {
    final seoData = _buildSeoData();

    final response = await http.post(
      Uri.parse('$_baseUrl/wordpress_publish.php?action=${asDraft ? 'draft' : 'publish'}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'site_id': _selectedSiteId,
        'title': _titleController.text.trim(),
        'content': _deltaToHtml(),
        'excerpt': _excerptController.text.trim(),
        'categories': _selectedCategories,
        'tags': _selectedTags,
        'featured_media': _featuredMediaId ?? 0,
        'author_id': _selectedAuthorId ?? 0,
        'author_name': _authors.firstWhere(
          (a) => a['id'] == _selectedAuthorId,
          orElse: () => {'name': widget.username},
        )['name'],
        ...seoData,
      }),
    );

    final data = jsonDecode(response.body);
    if (data['success'] == true) {
      final post = data['post'];
      _showSuccessDialog(
        title: asDraft ? 'Draft Saved!' : 'Published!',
        message: data['message'],
        results: [
          {
            'site_name': _sites.firstWhere((s) => s['id'] == _selectedSiteId)['name'],
            'success': true,
            'link': post['link'],
          }
        ],
      );
    } else {
      _showError(data['error'] ?? 'Failed to publish');
    }
  }

  Future<void> _publishToGroup(bool asDraft) async {
    // Parse category and tag names
    final categoryNames = _categoryNamesController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final tagNames = _tagNamesController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final seoData = _buildSeoData();

    final response = await http.post(
      Uri.parse('$_baseUrl/wordpress_publish.php?action=${asDraft ? 'draft_group' : 'publish_group'}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'group_id': _selectedGroupId,
        'title': _titleController.text.trim(),
        'content': _deltaToHtml(),
        'excerpt': _excerptController.text.trim(),
        'category_names': categoryNames,
        'tag_names': tagNames,
        'author_name': widget.username,
        ...seoData,
      }),
    );

    final data = jsonDecode(response.body);
    if (data['success'] == true) {
      _showSuccessDialog(
        title: asDraft ? 'Drafts Saved!' : 'Published!',
        message: data['message'],
        results: List<Map<String, dynamic>>.from(data['results'] ?? []),
      );
    } else {
      _showError(data['error'] ?? 'Failed to publish');
    }
  }

  void _showSuccessDialog({
    required String title,
    required String message,
    required List<Map<String, dynamic>> results,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final result = results[index];
                    final success = result['success'] == true;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            success ? Icons.check_circle : Icons.error,
                            color: success ? Colors.green : Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  result['site_name'] ?? 'Unknown',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                if (result['geo_location'] != null)
                                  Text(
                                    result['geo_location'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                if (!success && result['error'] != null)
                                  Text(
                                    result['error'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (success && result['link'] != null)
                            IconButton(
                              icon: const Icon(Icons.open_in_new, size: 18),
                              onPressed: () => _launchUrl(result['link']),
                              tooltip: result['link'],
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearForm();
            },
            child: const Text('New Post'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  /// Generate URL slug from title
  void _generateSlugFromTitle() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _slugController.clear();
      return;
    }

    // Convert title to URL-friendly slug
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'#geolocation', caseSensitive: false), '') // Remove geo placeholder
        .replaceAll(RegExp(r'[^\w\s-]'), '') // Remove special characters except hyphens
        .replaceAll(RegExp(r'\s+'), '-') // Replace spaces with hyphens
        .replaceAll(RegExp(r'-+'), '-') // Remove consecutive hyphens
        .replaceAll(RegExp(r'^-|-$'), ''); // Remove leading/trailing hyphens

    _slugController.text = slug;
  }

  void _clearForm() {
    _titleController.clear();
    _slugController.clear();
    _quillController.clear();
    _excerptController.clear();
    _seoTitleController.clear();
    _seoDescriptionController.clear();
    _focusKeyphraseController.clear();
    _keyphrasesynonymsController.clear();
    _canonicalUrlController.clear();
    _ogTitleController.clear();
    _ogDescriptionController.clear();
    _ogImageUrlController.clear();
    _twitterTitleController.clear();
    _twitterDescriptionController.clear();
    _twitterImageUrlController.clear();
    _categoryNamesController.clear();
    _tagNamesController.clear();
    for (final rk in _relatedKeyphrases) {
      rk['keyphrase']?.dispose();
      rk['synonyms']?.dispose();
    }
    setState(() {
      _selectedCategories = [];
      _selectedTags = [];
      _featuredMediaId = null;
      _featuredMediaUrl = null;
      _isCornerstone = false;
      _relatedKeyphrases.clear();
      // Reset author to default
      if (_authors.isNotEmpty) {
        final singlePostAuthor = _authors.firstWhere(
          (a) => a['name'].toString().toLowerCase() == 'single post',
          orElse: () => _authors.first,
        );
        _selectedAuthorId = singlePostAuthor['id'];
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green.shade700),
    );
  }

  /// Launch URL in external browser
  Future<void> _launchUrl(String? url) async {
    if (url == null || url.isEmpty) return;

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError('Could not open link');
      }
    } catch (e) {
      _showError('Invalid URL');
    }
  }

  /// Update word and character count
  void _updateWordCount() {
    final content = _getPlainText();
    final words = content.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final chars = content.length;

    if (mounted) {
      setState(() {
        _wordCount = words;
        _charCount = chars;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          isDark ? 'assets/images/logo-white.png' : 'assets/images/logo.png',
          height: 40,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _accent,
          labelColor: _accent,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(
              icon: const Icon(Icons.edit_note),
              text: _isEditMode ? 'Edit Post' : 'Create Post',
            ),
            const Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      backgroundColor: bgColor,
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Editor
          _isLoadingSites
              ? const Center(child: CircularProgressIndicator(color: _accent))
              : (_sites.isEmpty && _groups.isEmpty)
                  ? _buildNoSitesMessage(cardColor)
                  : _buildEditor(cardColor, isDark),
          // Tab 2: History
          _buildHistoryTab(cardColor, isDark),
        ],
      ),
    );
  }

  Widget _buildNoSitesMessage(Color cardColor) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.language_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No WordPress Sites Configured',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask an admin to add WordPress sites in\nManagement \u2192 WordPress Sites',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(Color cardColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_note, color: _accent, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Blog Article Creator',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Create and publish blog posts to WordPress sites',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Two column layout for desktop
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 700) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Main content column
                          Expanded(
                            flex: 2,
                            child: _buildMainContent(cardColor, isDark),
                          ),
                          const SizedBox(width: 20),
                          // Sidebar
                          SizedBox(
                            width: 320,
                            child: _buildSidebar(cardColor, isDark),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildMainContent(cardColor, isDark),
                          const SizedBox(height: 20),
                          _buildSidebar(cardColor, isDark),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(Color cardColor, bool isDark) {
    return Column(
      children: [
        // Geo-location hint
        _buildCard(
          cardColor: _accent.withValues(alpha: 0.1),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: _accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Geo-Replacement',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      'Use #GeoLocation in your content to automatically insert location names (e.g., "California", "Texas") based on each site\'s configured location.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Title
        _buildCard(
          cardColor: cardColor,
          child: TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Post Title',
              hintText: 'Enter your blog post title (use #GeoLocation for location)',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            validator: (v) => v?.trim().isEmpty == true ? 'Title is required' : null,
            onChanged: (_) => _generateSlugFromTitle(),
          ),
        ),
        const SizedBox(height: 16),

        // Slug (URL)
        _buildCard(
          cardColor: cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.link, color: _accent, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'URL Slug',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _generateSlugFromTitle,
                    icon: const Icon(Icons.auto_fix_high, size: 14),
                    label: const Text('Generate', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _slugController,
                decoration: InputDecoration(
                  hintText: 'post-url-slug',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  prefixText: '/',
                  prefixStyle: TextStyle(color: Colors.grey.shade400),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Content - Rich Text Editor
        _buildCard(
          cardColor: cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_note, color: _accent, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Content',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Use #GeoLocation for location text',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Custom Toolbar (flutter_quill's toolbar has Windows rendering issues)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Undo/Redo
                      _buildToolbarButton(Icons.undo, 'Undo', () {
                        _quillController.undo();
                      }),
                      _buildToolbarButton(Icons.redo, 'Redo', () {
                        _quillController.redo();
                      }),
                      _buildToolbarDivider(),
                      // Text formatting
                      _buildToolbarToggle(Icons.format_bold, 'Bold', Attribute.bold),
                      _buildToolbarToggle(Icons.format_italic, 'Italic', Attribute.italic),
                      _buildToolbarToggle(Icons.format_underline, 'Underline', Attribute.underline),
                      _buildToolbarToggle(Icons.format_strikethrough, 'Strikethrough', Attribute.strikeThrough),
                      _buildToolbarDivider(),
                      // Headers
                      _buildHeaderDropdown(),
                      _buildToolbarDivider(),
                      // Lists
                      _buildToolbarToggle(Icons.format_list_bulleted, 'Bullet List', Attribute.ul),
                      _buildToolbarToggle(Icons.format_list_numbered, 'Numbered List', Attribute.ol),
                      _buildToolbarDivider(),
                      // Alignment
                      _buildToolbarToggle(Icons.format_align_left, 'Align Left', Attribute.leftAlignment),
                      _buildToolbarToggle(Icons.format_align_center, 'Center', Attribute.centerAlignment),
                      _buildToolbarToggle(Icons.format_align_right, 'Align Right', Attribute.rightAlignment),
                      _buildToolbarDivider(),
                      // Other
                      _buildToolbarToggle(Icons.format_quote, 'Quote', Attribute.blockQuote),
                      _buildToolbarButton(Icons.link, 'Insert Link', _insertLink),
                      _buildToolbarButton(Icons.format_clear, 'Clear Format', () {
                        _quillController.formatSelection(Attribute.clone(Attribute.bold, null));
                        _quillController.formatSelection(Attribute.clone(Attribute.italic, null));
                        _quillController.formatSelection(Attribute.clone(Attribute.underline, null));
                        _quillController.formatSelection(Attribute.clone(Attribute.strikeThrough, null));
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Quill Editor
              Container(
                height: 350,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: isDark ? Colors.grey.shade900 : Colors.white,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: QuillEditor.basic(
                    controller: _quillController,
                    focusNode: _editorFocusNode,
                    scrollController: _editorScrollController,
                    config: const QuillEditorConfig(
                      placeholder: 'Write your blog post content here...',
                      padding: EdgeInsets.all(12),
                      expands: true,
                      autoFocus: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Word and character count
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _wordCount >= 300
                          ? Colors.green.withValues(alpha: 0.1)
                          : _wordCount >= 100
                              ? Colors.orange.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.text_fields,
                          size: 14,
                          color: _wordCount >= 300
                              ? Colors.green
                              : _wordCount >= 100
                                  ? Colors.orange
                                  : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_wordCount words',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _wordCount >= 300
                                ? Colors.green
                                : _wordCount >= 100
                                    ? Colors.orange
                                    : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.abc, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '$_charCount chars',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Excerpt
        _buildCard(
          cardColor: cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Excerpt (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _excerptController,
                decoration: const InputDecoration(
                  hintText: 'Brief summary of the post (shown in previews)',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // SEO Analysis Panel (Yoast-style)
        _buildSeoAnalysisPanel(cardColor),
        const SizedBox(height: 16),

        // SEO Section - Main
        _buildCard(
          cardColor: cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.search, color: Colors.green, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Yoast SEO',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Cornerstone toggle
                  Tooltip(
                    message: 'Mark as cornerstone content (important articles)',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star,
                          size: 16,
                          color: _isCornerstone ? _accent : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Cornerstone',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isCornerstone ? _accent : Colors.grey,
                          ),
                        ),
                        Switch(
                          value: _isCornerstone,
                          onChanged: (v) => setState(() => _isCornerstone = v),
                          activeThumbColor: _accent,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _seoTitleController,
                decoration: InputDecoration(
                  labelText: 'SEO Title',
                  hintText: 'Custom title for search engines (use #GeoLocation)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _seoDescriptionController,
                decoration: InputDecoration(
                  labelText: 'Meta Description',
                  hintText: 'Description shown in search results (use #GeoLocation)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                maxLines: 3,
              ),
              const Divider(height: 24),
              // Focus Keyphrase section
              const Row(
                children: [
                  Icon(Icons.key, size: 16, color: Colors.green),
                  SizedBox(width: 6),
                  Text(
                    'Focus Keyphrase',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _focusKeyphraseController,
                decoration: InputDecoration(
                  labelText: 'Keyphrase',
                  hintText: 'Primary keyword for this post',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _keyphrasesynonymsController,
                decoration: InputDecoration(
                  labelText: 'Keyphrase Synonyms',
                  hintText: 'Comma-separated synonyms (e.g., chimney top cracks, crown damage)',
                  helperText: 'Yoast will check if these appear in your content',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const Divider(height: 24),
              // Related Keyphrases section
              Row(
                children: [
                  const Icon(Icons.link, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Related Keyphrases',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  Text(
                    '${_relatedKeyphrases.length}/4',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.green),
                    onPressed: _addRelatedKeyphrase,
                    tooltip: 'Add related keyphrase',
                    iconSize: 22,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              if (_relatedKeyphrases.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Add up to 4 related keyphrases to optimize for additional terms',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ..._relatedKeyphrases.asMap().entries.map((entry) {
                final index = entry.key;
                final rk = entry.value;
                return Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Related Keyphrase ${index + 1}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                            onPressed: () => _removeRelatedKeyphrase(index),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: rk['keyphrase'],
                        decoration: InputDecoration(
                          labelText: 'Keyphrase',
                          hintText: 'e.g., chimney crown cracks',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: rk['synonyms'],
                        decoration: InputDecoration(
                          labelText: 'Synonyms (optional)',
                          hintText: 'Comma-separated synonyms',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Advanced SEO Section (Collapsible)
        _buildCard(
          cardColor: cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() => _showAdvancedSeo = !_showAdvancedSeo),
                child: Row(
                  children: [
                    Icon(
                      _showAdvancedSeo ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.tune, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      'Advanced SEO',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
              ),
              if (_showAdvancedSeo) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _canonicalUrlController,
                  decoration: InputDecoration(
                    labelText: 'Canonical URL',
                    hintText: 'Leave empty to use default URL',
                    helperText: 'Set a custom canonical URL if this content appears elsewhere',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Social SEO Section (Collapsible)
        _buildCard(
          cardColor: cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() => _showSocialSeo = !_showSocialSeo),
                child: Row(
                  children: [
                    Icon(
                      _showSocialSeo ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.share, size: 16, color: Colors.purple),
                    const SizedBox(width: 8),
                    const Text(
                      'Social Media (Open Graph & Twitter)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
              ),
              if (_showSocialSeo) ...[
                const SizedBox(height: 16),
                // Open Graph
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1877F2).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1877F2).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.facebook, size: 18, color: Color(0xFF1877F2)),
                          SizedBox(width: 8),
                          Text(
                            'Facebook / Open Graph',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ogTitleController,
                        decoration: InputDecoration(
                          labelText: 'OG Title',
                          hintText: 'Title for Facebook sharing',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _ogDescriptionController,
                        decoration: InputDecoration(
                          labelText: 'OG Description',
                          hintText: 'Description for Facebook sharing',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _ogImageUrlController,
                        decoration: InputDecoration(
                          labelText: 'OG Image URL',
                          hintText: 'Image URL for Facebook sharing',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Twitter
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.alternate_email, size: 18, color: Colors.black87),
                          SizedBox(width: 8),
                          Text(
                            'X (Twitter)',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _twitterTitleController,
                        decoration: InputDecoration(
                          labelText: 'Twitter Title',
                          hintText: 'Title for Twitter/X sharing',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _twitterDescriptionController,
                        decoration: InputDecoration(
                          labelText: 'Twitter Description',
                          hintText: 'Description for Twitter/X sharing',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _twitterImageUrlController,
                        decoration: InputDecoration(
                          labelText: 'Twitter Image URL',
                          hintText: 'Image URL for Twitter/X sharing',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar(Color cardColor, bool isDark) {
    return Column(
      children: [
        // Publishing Mode Selection
        _buildCard(
          cardColor: cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Publishing Mode',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildModeButton(
                      label: 'Group',
                      icon: Icons.folder_copy,
                      isSelected: _publishMode == 'group',
                      onTap: () => setState(() => _publishMode = 'group'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildModeButton(
                      label: 'Single Site',
                      icon: Icons.language,
                      isSelected: _publishMode == 'single',
                      onTap: () => setState(() => _publishMode = 'single'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Group or Site Selection based on mode
        if (_publishMode == 'group')
          _buildGroupSelector(cardColor)
        else
          _buildSiteSelector(cardColor),

        // Author selector (only for single site mode)
        if (_publishMode == 'single') ...[
          const SizedBox(height: 16),
          _buildAuthorSelector(cardColor),
        ],

        const SizedBox(height: 16),

        // Featured Image
        _buildCard(
          cardColor: cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.image, color: _accent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Featured Image',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_featuredMediaUrl != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _featuredMediaUrl!,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 150,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                        ),
                        onPressed: () {
                          setState(() {
                            _featuredMediaId = null;
                            _featuredMediaUrl = null;
                          });
                        },
                      ),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: _isUploadingImage ? null : _uploadFeaturedImage,
                  icon: _isUploadingImage
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload),
                  label: Text(_isUploadingImage ? 'Uploading...' : 'Upload Image'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              if (_publishMode == 'group') ...[
                const SizedBox(height: 8),
                Text(
                  'Note: Featured image will be uploaded to the primary site only',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Categories and Tags for Group mode (text input)
        if (_publishMode == 'group') ...[
          _buildCard(
            cardColor: cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.folder, color: _accent, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Categories',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _categoryNamesController,
                  decoration: InputDecoration(
                    hintText: 'Enter category names, separated by commas',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Categories will be created if they don\'t exist',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildCard(
            cardColor: cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tag, color: _accent, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Tags',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tagNamesController,
                  decoration: InputDecoration(
                    hintText: 'Enter tag names, separated by commas',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tags will be created if they don\'t exist',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],

        // Categories/Tags for Single site mode (chip selection)
        if (_publishMode == 'single' && _selectedSiteId != null) ...[
          if (_isLoadingCategories)
            _buildCard(
              cardColor: cardColor,
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: _accent),
                ),
              ),
            )
          else if (_categories.isNotEmpty)
            _buildCard(
              cardColor: cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.folder, color: _accent, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Categories',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategories.contains(cat['id']);
                      return FilterChip(
                        label: Text(cat['name']),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedCategories.add(cat['id']);
                            } else {
                              _selectedCategories.remove(cat['id']);
                            }
                          });
                        },
                        selectedColor: _accent.withValues(alpha: 0.2),
                        checkmarkColor: _accent,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildCard(
              cardColor: cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tag, color: _accent, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Tags',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tags.map((tag) {
                      final isSelected = _selectedTags.contains(tag['id']);
                      return FilterChip(
                        label: Text(tag['name']),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedTags.add(tag['id']);
                            } else {
                              _selectedTags.remove(tag['id']);
                            }
                          });
                        },
                        selectedColor: _accent.withValues(alpha: 0.2),
                        checkmarkColor: _accent,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
        const SizedBox(height: 24),

        // Edit Mode Banner
        if (_isEditMode) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Editing existing post - changes will update on all published sites',
                    style: TextStyle(color: Colors.blue, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: _clearEditMode,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Action Buttons
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isPublishing ? null : () => _publish(asDraft: false),
            icon: _isPublishing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(_isEditMode ? Icons.save : Icons.publish),
            label: Text(_isPublishing
                ? (_isEditMode ? 'Updating...' : 'Publishing...')
                : _isEditMode
                    ? (_publishMode == 'group' ? 'Update All Sites' : 'Update Post')
                    : (_publishMode == 'group' ? 'Publish to All Sites' : 'Publish')),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isEditMode ? Colors.blue : _accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        if (!_isEditMode) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isPublishing ? null : () => _publish(asDraft: true),
              icon: const Icon(Icons.save_outlined),
              label: Text(_publishMode == 'group' ? 'Save Drafts to All Sites' : 'Save as Draft'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModeButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _accent.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? _accent : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? _accent : Colors.grey, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? _accent : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSelector(Color cardColor) {
    return _buildCard(
      cardColor: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.folder_copy, color: _accent, size: 18),
              SizedBox(width: 8),
              Text(
                'Select Group',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_groups.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No groups configured. Create groups in Management \u2192 WordPress Sites.',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            )
          else
            DropdownButtonFormField<int>(
              initialValue: _selectedGroupId,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              hint: const Text('Select group'),
              items: _groups.map((group) {
                final siteCount = group['site_count'] ?? 0;
                return DropdownMenuItem<int>(
                  value: group['id'],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(group['name'], overflow: TextOverflow.ellipsis),
                      Text(
                        '$siteCount site${siteCount == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedGroupId = value);
              },
            ),

          // Show sites in selected group
          if (_selectedGroupId != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Sites in this group:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            ..._buildGroupSitesList(),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildGroupSitesList() {
    final group = _groups.firstWhere(
      (g) => g['id'] == _selectedGroupId,
      orElse: () => {},
    );
    final sites = group['sites'] as List? ?? [];

    return sites.map<Widget>((site) {
      final isPrimary = site['is_primary'] == 1 || site['is_primary'] == true;
      final geoLocation = site['geo_location'] ?? '';
      final geoEnabled = site['geo_enabled'] == 1 || site['geo_enabled'] == true;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              isPrimary ? Icons.star : Icons.language,
              size: 16,
              color: isPrimary ? _accent : Colors.grey,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    site['name'],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (geoLocation.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: geoEnabled ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          geoLocation,
                          style: TextStyle(
                            fontSize: 11,
                            color: geoEnabled ? Colors.green.shade700 : Colors.grey,
                            decoration: geoEnabled ? null : TextDecoration.lineThrough,
                          ),
                        ),
                        if (!geoEnabled) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(disabled)',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildSiteSelector(Color cardColor) {
    return _buildCard(
      cardColor: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.language, color: _accent, size: 18),
              SizedBox(width: 8),
              Text(
                'WordPress Site',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _selectedSiteId,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            hint: const Text('Select site'),
            items: _sites.map((site) {
              final groupName = site['group_name'];
              return DropdownMenuItem<int>(
                value: site['id'],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(site['name'], overflow: TextOverflow.ellipsis),
                    if (groupName != null)
                      Text(
                        groupName,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedSiteId = value);
              if (value != null) {
                _loadCategoriesAndTags(value);
                _loadAuthors(value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorSelector(Color cardColor) {
    return _buildCard(
      cardColor: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person, color: _accent, size: 18),
              SizedBox(width: 8),
              Text(
                'Author',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingAuthors)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
                ),
              ),
            )
          else if (_authors.isEmpty)
            Text(
              'Select a site to load authors',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          else
            DropdownButtonFormField<int>(
              initialValue: _selectedAuthorId,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              hint: const Text('Select author'),
              items: _authors.map((author) {
                return DropdownMenuItem<int>(
                  value: author['id'],
                  child: Text(author['name'], overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedAuthorId = value);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCard({required Color cardColor, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }

  Widget _buildSeoAnalysisPanel(Color cardColor) {
    // Determine overall status
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (_seoProblems.isNotEmpty) {
      statusColor = Colors.red;
      statusText = 'Needs Improvement';
      statusIcon = Icons.error_outline;
    } else if (_seoImprovements.isNotEmpty) {
      statusColor = Colors.orange;
      statusText = 'OK';
      statusIcon = Icons.warning_amber;
    } else if (_seoGood.isNotEmpty) {
      statusColor = Colors.green;
      statusText = 'Good';
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Colors.grey;
      statusText = 'Enter content to analyze';
      statusIcon = Icons.info_outline;
    }

    return _buildCard(
      cardColor: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with toggle
          InkWell(
            onTap: () => setState(() => _showSeoAnalysis = !_showSeoAnalysis),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SEO Analysis',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Score indicators
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_seoProblems.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.close, color: Colors.red, size: 12),
                            const SizedBox(width: 4),
                            Text('${_seoProblems.length}',
                              style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (_seoImprovements.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning, color: Colors.orange, size: 12),
                            const SizedBox(width: 4),
                            Text('${_seoImprovements.length}',
                              style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (_seoGood.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check, color: Colors.green, size: 12),
                            const SizedBox(width: 4),
                            Text('${_seoGood.length}',
                              style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  _showSeoAnalysis ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey,
                ),
              ],
            ),
          ),

          // Expanded analysis content
          if (_showSeoAnalysis) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Problems section
            if (_seoProblems.isNotEmpty) ...[
              _buildSeoSection(
                title: 'Problems',
                icon: Icons.error_outline,
                color: Colors.red,
                items: _seoProblems,
              ),
              const SizedBox(height: 12),
            ],

            // Improvements section
            if (_seoImprovements.isNotEmpty) ...[
              _buildSeoSection(
                title: 'Improvements',
                icon: Icons.warning_amber,
                color: Colors.orange,
                items: _seoImprovements,
              ),
              const SizedBox(height: 12),
            ],

            // Good section
            if (_seoGood.isNotEmpty)
              _buildSeoSection(
                title: 'Good results',
                icon: Icons.check_circle,
                color: Colors.green,
                items: _seoGood,
              ),

            // Related Keyphrases Analysis (Yoast Premium style)
            if (_relatedKeyphrasesAnalysis.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              ..._relatedKeyphrasesAnalysis.asMap().entries.map((entry) {
                final index = entry.key;
                final rkAnalysis = entry.value;
                final problems = List<Map<String, dynamic>>.from(rkAnalysis['problems'] ?? []);
                final goodResults = List<Map<String, dynamic>>.from(rkAnalysis['good'] ?? []);
                final hasProblems = problems.isNotEmpty;

                return _buildRelatedKeyphraseAnalysisPanel(
                  index: index,
                  keyphrase: rkAnalysis['keyphrase'] ?? '',
                  problems: problems,
                  goodResults: goodResults,
                  hasProblems: hasProblems,
                );
              }),
            ],

            // Empty state
            if (_seoProblems.isEmpty && _seoImprovements.isEmpty && _seoGood.isEmpty && _relatedKeyphrasesAnalysis.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.analytics_outlined, size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        'Start writing to see SEO analysis',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSeoSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['message'],
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        if (item['detail'] != null)
                          Text(
                            item['detail'],
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildRelatedKeyphraseAnalysisPanel({
    required int index,
    required String keyphrase,
    required List<Map<String, dynamic>> problems,
    required List<Map<String, dynamic>> goodResults,
    required bool hasProblems,
  }) {
    // Use StatefulBuilder to manage expansion state locally
    return StatefulBuilder(
      builder: (context, setLocalState) {
        // Track expansion state in the analysis data
        final isExpanded = _relatedKeyphrasesAnalysis[index]['expanded'] ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              InkWell(
                onTap: () {
                  setLocalState(() {
                    _relatedKeyphrasesAnalysis[index]['expanded'] = !isExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: hasProblems
                              ? Colors.red.withValues(alpha: 0.1)
                              : Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          hasProblems ? Icons.error_outline : Icons.check_circle,
                          size: 16,
                          color: hasProblems ? Colors.red : Colors.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Related keyphrase',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              keyphrase,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Problem/Good count badges
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (problems.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.close, color: Colors.red, size: 10),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${problems.length}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (problems.isNotEmpty && goodResults.isNotEmpty)
                            const SizedBox(width: 4),
                          if (goodResults.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check, color: Colors.green, size: 10),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${goodResults.length}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              // Expanded content
              if (isExpanded) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Problems
                      if (problems.isNotEmpty) ...[
                        _buildSeoSection(
                          title: 'Problems (${problems.length})',
                          icon: Icons.error_outline,
                          color: Colors.red,
                          items: problems,
                        ),
                        if (goodResults.isNotEmpty)
                          const SizedBox(height: 12),
                      ],
                      // Good results
                      if (goodResults.isNotEmpty)
                        _buildSeoSection(
                          title: 'Good results (${goodResults.length})',
                          icon: Icons.check_circle,
                          color: Colors.green,
                          items: goodResults,
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // Custom toolbar helper methods
  Widget _buildToolbarButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: Colors.grey.shade700),
        ),
      ),
    );
  }

  Widget _buildToolbarToggle(IconData icon, String tooltip, Attribute attribute) {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        final isActive = _quillController.getSelectionStyle().attributes.containsKey(attribute.key);
        return Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: () {
              if (attribute.key == Attribute.ul.key || attribute.key == Attribute.ol.key ||
                  attribute.key == Attribute.blockQuote.key) {
                // Block-level attributes
                _quillController.formatSelection(
                  isActive ? Attribute.clone(attribute, null) : attribute,
                );
              } else if (attribute.key == Attribute.leftAlignment.key ||
                         attribute.key == Attribute.centerAlignment.key ||
                         attribute.key == Attribute.rightAlignment.key) {
                // Alignment - remove all first then apply
                _quillController.formatSelection(attribute);
              } else {
                // Inline attributes
                _quillController.formatSelection(
                  isActive ? Attribute.clone(attribute, null) : attribute,
                );
              }
              setLocalState(() {});
            },
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive ? _accent.withValues(alpha: 0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, size: 20, color: isActive ? _accent : Colors.grey.shade700),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolbarDivider() {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.grey.shade400,
    );
  }

  Widget _buildHeaderDropdown() {
    return PopupMenuButton<int>(
      tooltip: 'Heading Style',
      onSelected: (level) {
        if (level == 0) {
          _quillController.formatSelection(Attribute.clone(Attribute.header, null));
        } else {
          _quillController.formatSelection(HeaderAttribute(level: level));
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 0, child: Text('Normal')),
        const PopupMenuItem(value: 1, child: Text('Heading 1', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
        const PopupMenuItem(value: 2, child: Text('Heading 2', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        const PopupMenuItem(value: 3, child: Text('Heading 3', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.title, size: 20, color: Colors.grey.shade700),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade700),
          ],
        ),
      ),
    );
  }

  void _insertLink() async {
    final urlController = TextEditingController();
    String? errorMessage;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Insert Link'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://example.com',
                  errorText: errorMessage,
                ),
                autofocus: true,
                onChanged: (_) {
                  if (errorMessage != null) {
                    setDialogState(() => errorMessage = null);
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Only http:// and https:// URLs are allowed',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final url = urlController.text.trim();
                final validation = _validateUrl(url);
                if (validation != null) {
                  setDialogState(() => errorMessage = validation);
                } else {
                  Navigator.pop(ctx, url);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Insert'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      _quillController.formatSelection(LinkAttribute(result));
    }
  }

  /// Validate URL for safety (prevent javascript: and other malicious URLs)
  String? _validateUrl(String url) {
    if (url.isEmpty) {
      return 'URL is required';
    }

    // Trim and lowercase for checking
    final lowerUrl = url.toLowerCase().trim();

    // Block dangerous URL schemes
    final dangerousSchemes = [
      'javascript:',
      'data:',
      'vbscript:',
      'file:',
    ];

    for (final scheme in dangerousSchemes) {
      if (lowerUrl.startsWith(scheme)) {
        return 'This URL scheme is not allowed';
      }
    }

    // Must be http or https
    if (!lowerUrl.startsWith('http://') && !lowerUrl.startsWith('https://')) {
      // Allow relative URLs starting with /
      if (!lowerUrl.startsWith('/')) {
        return 'URL must start with http:// or https://';
      }
    }

    // Basic URL format validation
    try {
      if (lowerUrl.startsWith('http')) {
        Uri.parse(url);
      }
    } catch (_) {
      return 'Invalid URL format';
    }

    return null;
  }

  // ==================== HISTORY METHODS ====================

  /// Copy all blog titles from history to clipboard for AI spinning
  void _copyAllTitles() {
    if (_historyEntries.isEmpty) {
      _showError('No blog posts to copy');
      return;
    }

    // Extract all titles
    final titles = _historyEntries
        .map((entry) => entry['title']?.toString() ?? 'Untitled')
        .toList();

    // Format titles as a numbered list for easy AI prompting
    final formattedTitles = titles.asMap().entries
        .map((entry) => '${entry.key + 1}. ${entry.value}')
        .join('\n');

    // Create a copyable prompt with instructions
    final copyText = '''Here are my existing blog post titles:

$formattedTitles

Please create a new unique blog title based on a similar topic but with a different angle or focus.''';

    // Copy to clipboard
    Clipboard.setData(ClipboardData(text: copyText));

    // Show success with count
    _showSuccess('Copied ${titles.length} titles to clipboard with AI prompt');
  }

  Future<void> _loadHistory({bool refresh = false}) async {
    if (_isLoadingHistory) return;
    if (refresh) {
      _historyPage = 1;
      _historyEntries = [];
    }

    setState(() => _isLoadingHistory = true);

    try {
      final uri = Uri.parse('$_baseUrl/wordpress_publish.php').replace(
        queryParameters: {
          'action': 'history',
          'page': _historyPage.toString(),
          'per_page': '20',
          if (_historySearchQuery.isNotEmpty) 'search': _historySearchQuery,
        },
      );

      final response = await http.get(uri);
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        setState(() {
          if (refresh || _historyPage == 1) {
            _historyEntries = List<Map<String, dynamic>>.from(data['history']);
          } else {
            _historyEntries.addAll(List<Map<String, dynamic>>.from(data['history']));
          }
          _historyTotal = data['total'] ?? 0;
        });
      } else {
        _showError(data['error'] ?? 'Failed to load history');
      }
    } catch (e) {
      _showError('Error loading history: $e');
    } finally {
      setState(() => _isLoadingHistory = false);
    }
  }

  Widget _buildHistoryTab(Color cardColor, bool isDark) {
    return Column(
      children: [
        // Search bar and copy titles button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search blog posts...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _historySearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() => _historySearchQuery = '');
                              _loadHistory(refresh: true);
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: cardColor,
                  ),
                  onChanged: (value) {
                    setState(() => _historySearchQuery = value);
                  },
                  onSubmitted: (_) => _loadHistory(refresh: true),
                ),
              ),
              const SizedBox(width: 8),
              // Copy All Titles button
              Tooltip(
                message: 'Copy all titles for AI spinning',
                child: ElevatedButton.icon(
                  onPressed: _historyEntries.isEmpty ? null : _copyAllTitles,
                  icon: const Icon(Icons.copy_all, size: 18),
                  label: const Text('Copy Titles'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),

        // History list
        Expanded(
          child: _isLoadingHistory && _historyEntries.isEmpty
              ? const Center(child: CircularProgressIndicator(color: _accent))
              : _historyEntries.isEmpty
                  ? _buildEmptyHistory(cardColor)
                  : RefreshIndicator(
                      onRefresh: () => _loadHistory(refresh: true),
                      color: _accent,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _historyEntries.length + (_historyEntries.length < _historyTotal ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _historyEntries.length) {
                            // Load more button
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: _isLoadingHistory
                                    ? const CircularProgressIndicator(color: _accent)
                                    : TextButton.icon(
                                        onPressed: () {
                                          _historyPage++;
                                          _loadHistory();
                                        },
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Load More'),
                                      ),
                              ),
                            );
                          }
                          return _buildHistoryCard(_historyEntries[index], cardColor, isDark);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyHistory(Color cardColor) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No Blog History Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Published blog posts will appear here.\nCreate your first post in the Editor tab!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> entry, Color cardColor, bool isDark) {
    final isGroupPost = entry['publish_mode'] == 'group';
    final posts = List<Map<String, dynamic>>.from(entry['posts'] ?? []);
    final siteCount = posts.length;
    final createdAt = DateTime.tryParse(entry['created_at'] ?? '') ?? DateTime.now();
    final formattedDate = '${createdAt.month}/${createdAt.day}/${createdAt.year}';

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isGroupPost ? Colors.blue.withValues(alpha: 0.1) : _accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isGroupPost ? Icons.folder : Icons.article,
            color: isGroupPost ? Colors.blue : _accent,
            size: 24,
          ),
        ),
        title: Text(
          entry['title'] ?? 'Untitled',
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isGroupPost ? Icons.language : Icons.web,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    isGroupPost
                        ? '${entry['group_name'] ?? 'Group'} ($siteCount sites)'
                        : entry['site_name'] ?? 'Single Site',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  formattedDate,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: entry['status'] == 'publish'
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry['status'] == 'publish' ? 'Published' : 'Draft',
                    style: TextStyle(
                      fontSize: 10,
                      color: entry['status'] == 'publish' ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              color: _accent,
              tooltip: 'Edit',
              onPressed: () => _loadForEdit(entry['group_publish_id']),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20),
              color: Colors.red,
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(entry['group_publish_id'], isGroupPost, siteCount),
            ),
          ],
        ),
        children: [
          // Show posts in this group
          if (posts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  Text(
                    'Published to:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...posts.map((post) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                post['site_name'] ?? 'Unknown Site',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            if (post['geo_location'] != null && post['geo_location'].toString().isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  post['geo_location'],
                                  style: const TextStyle(fontSize: 10, color: Colors.blue),
                                ),
                              ),
                            const SizedBox(width: 8),
                            if (post['link'] != null && post['link'].toString().isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.open_in_new, size: 16),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'View Post',
                                onPressed: () => _launchUrl(post['link']),
                              ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ==================== EDIT MODE METHODS ====================

  Future<void> _loadForEdit(String groupPublishId) async {
    setState(() => _isLoadingSites = true);

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/wordpress_publish.php?action=history_detail&group_publish_id=$groupPublishId'),
      );
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        final content = data['content'];

        // Set text fields
        _titleController.text = content['title'] ?? '';
        _slugController.text = content['slug'] ?? '';
        _excerptController.text = content['excerpt'] ?? '';

        // SEO fields
        _seoTitleController.text = content['seo_title'] ?? '';
        _seoDescriptionController.text = content['seo_description'] ?? '';
        _focusKeyphraseController.text = content['focus_keyphrase'] ?? '';
        _keyphrasesynonymsController.text = content['keyphrase_synonyms'] ?? '';
        _canonicalUrlController.text = content['canonical_url'] ?? '';
        _isCornerstone = content['is_cornerstone'] == 1 || content['is_cornerstone'] == '1';

        // Open Graph fields
        _ogTitleController.text = content['og_title'] ?? '';
        _ogDescriptionController.text = content['og_description'] ?? '';
        _ogImageUrlController.text = content['og_image'] ?? '';

        // Twitter fields
        _twitterTitleController.text = content['twitter_title'] ?? '';
        _twitterDescriptionController.text = content['twitter_description'] ?? '';
        _twitterImageUrlController.text = content['twitter_image'] ?? '';

        // Related keyphrases
        _relatedKeyphrases.clear();
        final relatedKps = content['related_keyphrases'];
        if (relatedKps != null && relatedKps is List) {
          for (final rk in relatedKps) {
            _relatedKeyphrases.add({
              'keyphrase': TextEditingController(text: rk['keyphrase'] ?? ''),
              'synonyms': TextEditingController(text: rk['synonyms'] ?? ''),
            });
          }
        }

        // Featured image
        _featuredMediaId = content['featured_media_id'];
        _featuredMediaUrl = content['featured_media_url'];

        // Publishing mode
        _publishMode = content['publish_mode'] ?? 'group';
        if (_publishMode == 'group') {
          _selectedGroupId = content['group_id'];
          // Set category/tag names for group mode
          final catNames = content['category_names'];
          final tagNames = content['tag_names'];
          _categoryNamesController.text = catNames is List ? catNames.join(', ') : '';
          _tagNamesController.text = tagNames is List ? tagNames.join(', ') : '';
        } else {
          _selectedSiteId = content['site_id'];
          // Load categories/tags for single site
          if (_selectedSiteId != null) {
            await _loadCategoriesAndTags(_selectedSiteId!);
            // Set selected categories/tags
            final catIds = content['category_ids'];
            final tagIds = content['tag_ids'];
            if (catIds is List) {
              _selectedCategories = catIds.map<int>((e) => int.tryParse(e.toString()) ?? 0).toList();
            }
            if (tagIds is List) {
              _selectedTags = tagIds.map<int>((e) => int.tryParse(e.toString()) ?? 0).toList();
            }
          }
        }

        // Convert HTML content to Quill Delta
        final htmlContent = content['content'] ?? '';
        _loadHtmlToQuill(htmlContent);

        // Set edit mode
        setState(() {
          _isEditMode = true;
          _editingGroupPublishId = groupPublishId;
        });

        // Switch to editor tab
        _tabController.animateTo(0);

        _showSuccess('Content loaded for editing');
      } else {
        _showError(data['error'] ?? 'Failed to load content');
      }
    } catch (e) {
      _showError('Error loading content: $e');
    } finally {
      setState(() => _isLoadingSites = false);
    }
  }

  void _loadHtmlToQuill(String html) {
    // Dispose the old controller to prevent memory leak
    _quillController.removeListener(_runSeoAnalysis);
    _quillController.dispose();

    // Parse HTML and convert to Quill Delta
    final document = _htmlToDocument(html);

    // Create a new QuillController with the content
    _quillController = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );

    // Re-add the SEO listener
    _quillController.addListener(_runSeoAnalysis);

    // Update word count
    _updateWordCount();
  }

  /// Convert HTML to Quill Document
  /// This is a simplified converter that preserves basic formatting
  Document _htmlToDocument(String html) {
    // Unescape HTML entities first
    String cleanHtml = html
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    // Convert block elements to newlines
    cleanHtml = cleanHtml
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</h[1-6]>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</blockquote>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</(ul|ol)>', caseSensitive: false), '\n');

    // Strip remaining HTML tags
    final plainText = cleanHtml
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n') // Normalize multiple newlines
        .trim();

    // Create document with plain text
    // Note: This loses inline formatting (bold, italic, etc.) but preserves structure
    // For full formatting preservation, a more complex Delta-based approach would be needed
    final doc = Document();
    if (plainText.isNotEmpty) {
      doc.insert(0, plainText);
    }

    // Ensure document has content
    if (doc.isEmpty()) {
      doc.insert(0, '\n');
    }

    return doc;
  }

  void _clearEditMode() {
    setState(() {
      _isEditMode = false;
      _editingGroupPublishId = null;

      // Clear all fields
      _titleController.clear();
      _slugController.clear();
      _excerptController.clear();
      _seoTitleController.clear();
      _seoDescriptionController.clear();
      _focusKeyphraseController.clear();
      _keyphrasesynonymsController.clear();
      _canonicalUrlController.clear();
      _ogTitleController.clear();
      _ogDescriptionController.clear();
      _ogImageUrlController.clear();
      _twitterTitleController.clear();
      _twitterDescriptionController.clear();
      _twitterImageUrlController.clear();
      _categoryNamesController.clear();
      _tagNamesController.clear();

      _isCornerstone = false;
      _featuredMediaId = null;
      _featuredMediaUrl = null;
      _selectedCategories = [];
      _selectedTags = [];

      for (final rk in _relatedKeyphrases) {
        rk['keyphrase']?.dispose();
        rk['synonyms']?.dispose();
      }
      _relatedKeyphrases.clear();

      // Reset Quill controller
      _quillController = QuillController.basic();
      _quillController.addListener(_runSeoAnalysis);
    });
  }

  // ==================== DELETE METHODS ====================

  Future<void> _confirmDelete(String groupPublishId, bool isGroupPost, int siteCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 12),
            const Text('Confirm Deletion'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isGroupPost
                  ? 'This will permanently delete this post from ALL $siteCount sites in the group.'
                  : 'This will permanently delete this post from WordPress.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone!',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_forever),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deletePost(groupPublishId, isGroupPost);
    }
  }

  Future<void> _deletePost(String groupPublishId, bool isGroupPost) async {
    setState(() => _isLoadingHistory = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/wordpress_publish.php?action=${isGroupPost ? 'delete_group' : 'delete_post'}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'group_publish_id': groupPublishId}),
      );
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        _showSuccess(data['message'] ?? 'Post deleted successfully!');
        _loadHistory(refresh: true);
      } else {
        _showError(data['error'] ?? 'Failed to delete post');
      }
    } catch (e) {
      _showError('Error deleting post: $e');
    } finally {
      setState(() => _isLoadingHistory = false);
    }
  }
}
