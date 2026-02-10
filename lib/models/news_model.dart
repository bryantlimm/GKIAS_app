import 'package:cloud_firestore/cloud_firestore.dart';

class NewsItem {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String imageUrl;
  final String? pdfUrl; // nullable because not every news has a PDF

  NewsItem({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.imageUrl,
    this.pdfUrl,
  });

  // This "Factory" converts the weird Firestore format into our nice Flutter object
  factory NewsItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return NewsItem(
      id: doc.id,
      title: data['title'] ?? 'No Title',
      content: data['content'] ?? '',
      // We convert Firestore "Timestamp" to a Flutter "DateTime"
      date: (data['date'] as Timestamp).toDate(),
      imageUrl: data['imageUrl'] ?? '',
      pdfUrl: data['pdfUrl'],
    );
  }
}