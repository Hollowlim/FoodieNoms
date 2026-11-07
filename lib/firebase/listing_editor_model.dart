import 'dart:convert';

const listingCategories = ['Bakery', 'Meals', 'Pastries', 'Other'];
const listingDietaryTags = ['Vegetarian', 'Vegan', 'Gluten-free', 'Dairy-free'];
const listingHalalStatuses = ['not_declared', 'vendor_declared'];

/// Integer arithmetic avoids rounding a vendor's entered Ringgit amount.
int? listingRmCents(String text) {
  final value = text.trim();
  if (!RegExp(r'^\d{1,6}(\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final amount = int.parse(parts[0]) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  return amount > 0 && amount <= 1000000 ? amount : null;
}

int? listingQuantity(String text, {bool allowZero = false}) {
  if (!RegExp(r'^\d{1,5}$').hasMatch(text.trim())) return null;
  final quantity = int.parse(text.trim());
  return quantity >= (allowZero ? 0 : 1) && quantity <= 10000 ? quantity : null;
}

String listingMoney(int cents) =>
    'RM ${(cents ~/ 100)}.${(cents % 100).toString().padLeft(2, '0')}';

class ListingEditorModel {
  ListingEditorModel(
      {this.title = '',
      this.category = 'Meals',
      this.description = '',
      this.foodDescription = '',
      this.ingredients = '',
      this.allergens = '',
      this.pickupInstructions = '',
      List<String>? dietaryTags,
      this.halalStatus = 'not_declared',
      this.dietary = '',
      this.priceText = '',
      this.originalPriceText = '',
      this.quantityText = '',
      this.startsNow = true,
      this.pickupStart,
      this.pickupEnd,
      this.imageKey = 'photo-1',
      this.imageId})
      : dietaryTags = dietaryTags ?? [];

  String title, category, description, foodDescription;
  String ingredients, allergens, pickupInstructions, halalStatus, dietary;
  String priceText, originalPriceText, quantityText, imageKey;
  List<String> dietaryTags;
  bool startsNow;
  int? pickupStart, pickupEnd;
  String? imageId;

  factory ListingEditorModel.empty({DateTime? now}) {
    final time = now ?? DateTime.now();
    return ListingEditorModel(
        pickupStart: time.millisecondsSinceEpoch,
        pickupEnd: time.add(const Duration(hours: 2)).millisecondsSinceEpoch);
  }

  factory ListingEditorModel.fromDraft(Map<String, dynamic> data) =>
      ListingEditorModel(
          title: data['title'] as String? ?? '',
          category: listingCategories.contains(data['category'])
              ? data['category'] as String
              : 'Meals',
          description: data['description'] as String? ?? '',
          foodDescription: data['foodDescription'] as String? ?? '',
          ingredients: data['ingredients'] as String? ?? '',
          allergens: data['allergens'] as String? ?? '',
          pickupInstructions: data['pickupInstructions'] as String? ?? '',
          dietaryTags: {
            for (final tag in data['dietaryTags'] as List? ?? [])
              if (listingDietaryTags.contains(tag)) tag as String,
          }.toList(),
          halalStatus: listingHalalStatuses.contains(data['halalStatus'])
              ? data['halalStatus'] as String
              : 'not_declared',
          dietary: data['dietary'] as String? ?? '',
          priceText: data['priceText'] as String? ?? '',
          originalPriceText: data['originalPriceText'] as String? ?? '',
          quantityText: data['quantityText'] as String? ?? '',
          startsNow: data['startsNow'] as bool? ?? false,
          pickupStart: (data['pickupStart'] as num?)?.toInt(),
          pickupEnd: (data['pickupEnd'] as num?)?.toInt(),
          imageKey: RegExp(r'^photo-[0-3]$').hasMatch('${data['imageKey']}')
              ? data['imageKey'] as String
              : 'photo-1',
          imageId: data['imageId'] as String?);

  factory ListingEditorModel.fromListing(Map<String, dynamic> data,
      {bool duplicate = false}) {
    final model = ListingEditorModel.fromDraft({
      ...data,
      'priceText': data['priceCents'] is int
          ? ((data['priceCents'] as int) / 100).toStringAsFixed(2)
          : '',
      'originalPriceText': data['originalPriceCents'] is int
          ? ((data['originalPriceCents'] as int) / 100).toStringAsFixed(2)
          : '',
      'quantityText': data['stock'] == null ? '' : '${data['stock']}',
      'startsNow': false,
    });
    if (duplicate) {
      model.priceText = '';
      model.originalPriceText = '';
      model.quantityText = '';
      model.pickupStart = null;
      model.pickupEnd = null;
    }
    return model;
  }

  ListingEditorModel copy() => ListingEditorModel.fromDraft(toDraft());

  /// Fixed shape also preserves partially entered amounts such as `12.`.
  Map<String, dynamic> toDraft() => {
        'title': title,
        'category': category,
        'description': description,
        'foodDescription': foodDescription,
        'ingredients': ingredients,
        'allergens': allergens,
        'pickupInstructions': pickupInstructions,
        'dietaryTags': [...dietaryTags],
        'halalStatus': halalStatus,
        'dietary': dietary,
        'priceText': priceText,
        'originalPriceText': originalPriceText,
        'quantityText': quantityText,
        'startsNow': startsNow,
        'pickupStart': pickupStart,
        'pickupEnd': pickupEnd,
        'imageKey': imageKey,
        'imageId': imageId,
      };

  String get fingerprint => jsonEncode(toDraft());
  int? get studentCents => listingRmCents(priceText);
  int? get originalCents => listingRmCents(originalPriceText);
  int? get savingsCents => studentCents != null &&
          originalCents != null &&
          studentCents! < originalCents!
      ? originalCents! - studentCents!
      : null;
  int? get discountPercent => savingsCents == null
      ? null
      : (savingsCents! * 100 / originalCents!).round();

  String get dietarySummary {
    final pieces = <String>[
      if (ingredients.trim().isNotEmpty) 'Ingredients: ${ingredients.trim()}',
      if (allergens.trim().isNotEmpty) 'Allergens: ${allergens.trim()}',
      if (dietaryTags.isNotEmpty) 'Vendor declares: ${dietaryTags.join(', ')}',
      if (halalStatus == 'vendor_declared')
        'Halal: vendor declared; certification not verified',
    ];
    if (pieces.isEmpty && dietary.trim().isNotEmpty) {
      return dietary.trim().length <= 500
          ? dietary.trim()
          : 'Dietary and allergen details need confirmation. Ask the vendor.';
    }
    if (pieces.isEmpty) {
      return 'Dietary and allergen details not declared. Ask the vendor.';
    }
    final summary = pieces.join(' · ');
    return summary.length <= 500
        ? summary
        : 'See the vendor’s full ingredients and allergen details. Ask the vendor before consuming.';
  }

  Map<String, String> validateStep(int step,
      {DateTime? now, bool editing = false}) {
    final errors = <String, String>{};
    if (step == 0) {
      if (title.trim().isEmpty || title.trim().length > 100) {
        errors['title'] = 'Enter a food name of 1–100 characters.';
      }
      if (!listingCategories.contains(category)) {
        errors['category'] = 'Choose a food category.';
      }
      if (description.trim().isEmpty || description.trim().length > 1000) {
        errors['description'] =
            'Describe what is included (up to 1,000 characters).';
      }
      if (foodDescription.length > 1000) {
        errors['foodDescription'] = 'Use up to 1,000 characters.';
      }
      for (final entry in {
        'ingredients': ingredients,
        'allergens': allergens,
        'pickupInstructions': pickupInstructions,
      }.entries) {
        if (entry.value.length > 500) {
          errors[entry.key] = 'Use up to 500 characters.';
        }
      }
    } else if (step == 1) {
      if (originalCents == null) {
        errors['originalPriceText'] =
            'Enter RM 0.01–10,000.00 with up to 2 decimals.';
      }
      if (studentCents == null) {
        errors['priceText'] = 'Enter RM 0.01–10,000.00 with up to 2 decimals.';
      } else if (originalCents != null && studentCents! >= originalCents!) {
        errors['priceText'] =
            'Student price must be lower than the original price.';
      }
      if (listingQuantity(quantityText, allowZero: editing) == null) {
        errors['quantityText'] = editing
            ? 'Enter 0–10,000 whole items.'
            : 'Enter 1–10,000 whole items.';
      }
    } else if (step == 2) {
      final time = (now ?? DateTime.now()).millisecondsSinceEpoch;
      final start = startsNow ? time : pickupStart;
      if (start == null) {
        errors['pickupStart'] = 'Choose a pickup start date and time.';
      } else if (!editing && start < time - 300000) {
        errors['pickupStart'] =
            'A new pickup window may start now or up to 5 minutes ago.';
      }
      if (pickupEnd == null) {
        errors['pickupEnd'] = 'Choose a pickup end date and time.';
      } else if (pickupEnd! <= time || (start != null && pickupEnd! <= start)) {
        errors['pickupEnd'] =
            'Pickup must end after its start and in the future.';
      } else if (pickupEnd! > time + const Duration(days: 30).inMilliseconds) {
        errors['pickupEnd'] = 'Choose a pickup end within the next 30 days.';
      }
      if (pickupInstructions.length > 500) {
        errors['pickupInstructions'] = 'Use up to 500 characters.';
      }
    }
    return errors;
  }

  Map<String, dynamic> toListingData(
      {DateTime? now,
      bool editing = false,
      int? initialStock,
      int? expectedStock}) {
    final time = now ?? DateTime.now();
    for (var step = 0; step < 3; step++) {
      final errors = validateStep(step, now: time, editing: editing);
      if (errors.isNotEmpty) throw StateError(errors.values.first);
    }
    final quantity = listingQuantity(quantityText, allowZero: editing)!;
    final baselineStock = expectedStock ?? initialStock;
    return {
      'title': title.trim(),
      'category': category,
      'description': description.trim(),
      'foodDescription': foodDescription.trim(),
      'ingredients': ingredients.trim(),
      'allergens': allergens.trim(),
      'pickupInstructions': pickupInstructions.trim(),
      'dietaryTags': [...dietaryTags],
      'halalStatus': halalStatus,
      'dietary': dietarySummary,
      'priceCents': studentCents!,
      'originalPriceCents': originalCents!,
      if (!editing || quantity != baselineStock) 'stock': quantity,
      if (editing && quantity != baselineStock && expectedStock != null)
        'expectedStock': expectedStock,
      'pickupStart': startsNow ? time.millisecondsSinceEpoch : pickupStart!,
      'pickupEnd': pickupEnd!,
      'imageKey': imageKey,
      if (imageId != null || editing) 'imageId': imageId,
    };
  }
}
