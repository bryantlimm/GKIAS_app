import 'package:flutter/material.dart';
import '../models/news_model.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsDetailScreen extends StatelessWidget {
  // This screen needs a specific NewsItem to display
  final NewsItem news;

  const NewsDetailScreen({super.key, required this.news});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Warta'),
      ),
      body: SingleChildScrollView( // Allows scrolling if text is long
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. The Big Image
            if (news.imageUrl.isNotEmpty)
              Image.network(
                news.imageUrl,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox(height: 250, child: Center(child: Icon(Icons.broken_image, size: 60))),
              ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. The Title
                  Text(
                    news.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 3. The Date
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMMM yyyy').format(news.date),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 4. The Full Content
                  Text(
                    news.content,
                    style: const TextStyle(fontSize: 16, height: 1.5), // height makes text easier to read
                  ),
                  
                  // 5. PDF Button
                  if (news.pdfUrl != null) ...[
                    const SizedBox(height: 30),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final Uri url = Uri.parse(news.pdfUrl!);
                          
                          // Try to launch the URL in an external browser (Safari/Chrome)
                          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                            // If it fails, show a message
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not open PDF')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Download / View PDF'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20), // Extra space at bottom
                  ],
                  ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}