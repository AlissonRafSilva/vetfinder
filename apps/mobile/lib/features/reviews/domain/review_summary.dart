import '../../../core/formatters/opportunity_formatter.dart';

class ReviewSummary {
  const ReviewSummary({
    required this.id,
    required this.reviewerUserId,
    required this.reviewerName,
    required this.revieweeName,
    required this.rating,
    required this.ratingLabel,
    required this.comment,
    required this.createdAtLabel,
  });

  final String id;
  final String reviewerUserId;
  final String reviewerName;
  final String revieweeName;
  final int rating;
  final String ratingLabel;
  final String comment;
  final String createdAtLabel;

  factory ReviewSummary.fromJson(Map<String, dynamic> json) {
    final rating = int.tryParse(json['rating']?.toString() ?? '') ?? 0;
    final reviewer = _userName(json['reviewer']);
    final reviewee = _userName(json['reviewee']);

    return ReviewSummary(
      id: json['id']?.toString() ?? '',
      reviewerUserId: json['reviewerUserId']?.toString() ?? '',
      reviewerName: reviewer,
      revieweeName: reviewee,
      rating: rating,
      ratingLabel: _ratingLabel(rating),
      comment: json['comment']?.toString() ?? '',
      createdAtLabel: _createdAtLabel(json['createdAt']?.toString() ?? ''),
    );
  }

  static String _userName(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return 'Usuario';
    }

    final profile = value['profile'];
    if (profile is Map<String, dynamic>) {
      final fullName = profile['fullName']?.toString();
      if (fullName != null && fullName.isNotEmpty) {
        return fullName;
      }
    }

    final institution = value['institution'];
    if (institution is Map<String, dynamic>) {
      final tradeName = institution['tradeName']?.toString();
      if (tradeName != null && tradeName.isNotEmpty) {
        return tradeName;
      }

      final legalName = institution['legalName']?.toString();
      if (legalName != null && legalName.isNotEmpty) {
        return legalName;
      }
    }

    return value['email']?.toString() ?? 'Usuario';
  }

  static String _ratingLabel(int rating) {
    if (rating <= 0) {
      return 'Sem nota';
    }

    return 'Nota $rating/5';
  }

  static String _createdAtLabel(String createdAt) {
    final parsed = DateTime.tryParse(createdAt)?.toLocal();
    if (parsed == null) {
      return 'Avaliacao sem data';
    }

    return '${OpportunityFormatter.shortDate(parsed)} as ${OpportunityFormatter.hourLabel(parsed)}';
  }
}
