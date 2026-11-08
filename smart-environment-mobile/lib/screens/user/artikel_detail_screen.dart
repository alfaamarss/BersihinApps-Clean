import 'package:beresin_app/utils/app_log.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../models/artikel_model.dart';
import '../../services/artikel_service.dart';

class ArtikelDetailScreen extends StatefulWidget {
  final ArtikelModel? article;
  final int? articleId;
  final String? articleSlug;

  const ArtikelDetailScreen({
    super.key,
    this.article,
    this.articleId,
    this.articleSlug,
  }) : assert(
         article != null || articleId != null || articleSlug != null,
         'Either article, articleId, or articleSlug must be provided',
       );

  @override
  State<ArtikelDetailScreen> createState() => _ArtikelDetailScreenState();
}

class _ArtikelDetailScreenState extends State<ArtikelDetailScreen> {
  final ArtikelService _artikelService = ArtikelService();
  ArtikelModel? _article;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Always fetch detail from API to get full content
    // The article passed from list might only have summary, not full content
    _loadArticleDetail();
  }

  Future<void> _loadArticleDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use article ID if available, otherwise use provided identifiers
      final identifier = widget.article?.id ?? widget.articleId ?? widget.articleSlug;
      
      if (identifier == null) {
        throw Exception('Tidak ada identifier artikel');
      }
      
      appLog('[ARTICLE] Fetching detail for article: $identifier');
      
      final article = await _artikelService.getArticleDetail(identifier);
      
      appLog('[ARTICLE] ====== API Response ======');
      appLog('[ARTICLE] Title: ${article.title}');
      appLog('[ARTICLE] Content length: ${article.content.length} chars');
      appLog('[ARTICLE] Excerpt length: ${article.excerpt?.length ?? 0} chars');
      appLog('[ARTICLE] Content preview: ${article.content.substring(0, article.content.length > 200 ? 200 : article.content.length)}...');
      appLog('[ARTICLE] Full content: ${article.content}');
      appLog('[ARTICLE] ============================');
      
      setState(() {
        _article = article;
        _isLoading = false;
      });
    } catch (e) {
      appLog('[ARTICLE] Error loading detail: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Text(
          "Detail Artikel",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat artikel',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadArticleDetail,
              icon: const Icon(Icons.refresh),
              label: Text('Coba Lagi', style: GoogleFonts.poppins()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF009688),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_article == null) {
      return const Center(child: Text('Artikel tidak ditemukan'));
    }

    final imageUrl =
        _article!.imageUrl ??
        'https://via.placeholder.com/400x220?text=No+Image';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gambar Header
          Image.network(
            imageUrl,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: double.infinity,
              height: 220,
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
              ),
            ),
          ),

          // Judul Artikel
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _article!.title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),

          // Meta Information
          if (_article!.author != null || _article!.publishedAt != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (_article!.author != null) ...[
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _article!.author!,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (_article!.publishedAt != null) ...[
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(_article!.publishedAt!),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 8),

          // View Count
          if (_article!.viewCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_article!.viewCount} kali dilihat',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Ringkasan/Summary Section - Always show if available
          if (_article!.excerpt != null && _article!.excerpt!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label "Ringkasan"
                  Row(
                    children: [
                      Icon(
                        Icons.summarize_outlined,
                        size: 18,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ringkasan',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Summary Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Html(
                      data: _article!.excerpt!,
                      style: {
                        "body": Style(
                          fontSize: FontSize(14),
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[700],
                          fontFamily: GoogleFonts.poppins().fontFamily,
                          lineHeight: const LineHeight(1.5),
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                        ),
                        "p": Style(margin: Margins.only(bottom: 8)),
                        "span": Style(),
                      },
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // Divider between summary and full content
          if (_article!.excerpt != null && _article!.excerpt!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Isi Lengkap',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Isi Artikel Lengkap (Full HTML Content)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Html(
              data: _article!.content,
              style: {
                "body": Style(
                  fontSize: FontSize(15),
                  lineHeight: const LineHeight(1.6),
                  color: Colors.black87,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                ),
                "p": Style(margin: Margins.only(bottom: 12)),
                "h1": Style(
                  fontSize: FontSize(24),
                  fontWeight: FontWeight.bold,
                  margin: Margins.only(top: 16, bottom: 8),
                ),
                "h2": Style(
                  fontSize: FontSize(20),
                  fontWeight: FontWeight.bold,
                  margin: Margins.only(top: 14, bottom: 8),
                ),
                "h3": Style(
                  fontSize: FontSize(18),
                  fontWeight: FontWeight.bold,
                  margin: Margins.only(top: 12, bottom: 8),
                ),
                "img": Style(margin: Margins.symmetric(vertical: 12)),
                "a": Style(
                  color: const Color(0xFF009688),
                  textDecoration: TextDecoration.underline,
                ),
              },
            ),
          ),

          // Tags
          if (_article!.tags != null && _article!.tags!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _article!.tags!.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF009688).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF009688).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      tag,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF009688),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
