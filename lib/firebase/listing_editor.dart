import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'listing_editor_model.dart';
import 'listing_photo.dart';
import 'live_location_map.dart';
import 'management_ui.dart';
import 'reference_assets.dart';
import 'service.dart';
import 'student_experience.dart';
import 'student_ui.dart';

typedef EditorSaveDraft = Future<void> Function(
    ListingEditorModel model, Uint8List? photoBytes);
typedef EditorPublish = Future<void> Function(
    ListingEditorModel model, Uint8List? photoBytes, int? expectedStock);
typedef EditorPickPhoto = Future<EditorPhotoSelection?> Function(
    ImageSource source);
typedef EditorPickTime = Future<DateTime?> Function(
    bool start, DateTime? current);

class EditorPhotoSelection {
  const EditorPhotoSelection({required this.id, required this.photo});
  final String id;
  final PreparedListingPhoto photo;
}

class ListingEditorScreen extends StatefulWidget {
  const ListingEditorScreen(
      {super.key,
      required this.service,
      required this.business,
      this.listingId,
      this.initial,
      this.draftId,
      this.draftData,
      this.duplicate = false});
  final FoodieService service;
  final Map<String, dynamic> business;
  final String? listingId, draftId;
  final Map<String, dynamic>? initial, draftData;
  final bool duplicate;

  @override
  State<ListingEditorScreen> createState() => _ListingEditorScreenState();
}

class _ListingEditorScreenState extends State<ListingEditorScreen> {
  final picker = FoodPhotoPicker();
  final progress = ValueNotifier<String?>(null);
  late final String editorId = widget.draftId ?? widget.service.requestId();
  late final bool editing = widget.listingId != null && !widget.duplicate;
  late bool savedDraft = widget.draftId != null;
  late final Future<_EditorInitial> initial = initialize();

  void setProgress(String? message) {
    if (mounted) progress.value = message;
  }

  String get uid {
    final user = widget.service.auth.currentUser;
    if (user == null) throw StateError('Sign in as a vendor first.');
    return user.uid;
  }

  Future<_EditorInitial> initialize() async {
    final model = widget.draftData != null
        ? ListingEditorModel.fromDraft(widget.draftData!)
        : widget.initial != null
            ? ListingEditorModel.fromListing(widget.initial!,
                duplicate: widget.duplicate)
            : ListingEditorModel.empty();
    final savedData = model.toDraft();
    PreparedListingPhoto? recovered;
    String? recoveryError;
    if (widget.draftId != null) {
      try {
        recovered = await picker.recover(uid: uid, draftId: editorId);
        if (recovered != null) model.imageId = widget.service.requestId();
      } on FoodPhotoException catch (error) {
        recoveryError = error.message;
      } catch (_) {
        recoveryError =
            'The previous photo could not be recovered. You can select it again.';
      }
    }
    return _EditorInitial(
        model, savedData, recovered?.bytes, recovered != null, recoveryError);
  }

  Future<void> upload(ListingEditorModel model, Uint8List? bytes) async {
    if (bytes == null || model.imageId == null) return;
    setProgress('Uploading food photo…');
    await widget.service.uploadListingPhoto(model.imageId!, bytes);
  }

  Future<void> save(ListingEditorModel model, Uint8List? bytes) async {
    try {
      await upload(model, bytes);
      setProgress('Saving your draft…');
      await widget.service.saveListingDraft(editorId, model.toDraft(),
          sourceListingId: editing ? widget.listingId : null);
      savedDraft = true;
      try {
        await picker.clearRecovery(uid: uid, draftId: editorId);
      } catch (_) {}
    } finally {
      setProgress(null);
    }
  }

  Future<EditorPhotoSelection?> pick(ImageSource source) async {
    setProgress('Preparing food photo…');
    try {
      final photo = await picker.pick(source, uid: uid, draftId: editorId);
      return photo == null
          ? null
          : EditorPhotoSelection(id: widget.service.requestId(), photo: photo);
    } finally {
      setProgress(null);
    }
  }

  Future<void> publish(
      ListingEditorModel model, Uint8List? bytes, int? expectedStock) async {
    try {
      // Revalidate before upload and recompute Starts Now again before commit.
      model.toListingData(
          editing: editing,
          initialStock: widget.initial?['stock'] as int?,
          expectedStock: expectedStock);
      await upload(model, bytes);
      setProgress(
          editing ? 'Saving listing changes…' : 'Publishing your food…');
      final data = model.toListingData(
          editing: editing,
          initialStock: widget.initial?['stock'] as int?,
          expectedStock: expectedStock);
      await widget.service.call(editing ? 'editListing' : 'publishListing', {
        ...data,
        if (editing) 'listingId': widget.listingId,
        if (!editing) 'requestId': editorId,
        if (savedDraft) 'draftId': editorId,
      });
      // Recovery metadata cleanup must not turn a committed publication into
      // an apparent failure that encourages another submission.
      try {
        await picker.clearRecovery(uid: uid, draftId: editorId);
      } catch (_) {}
    } finally {
      setProgress(null);
    }
  }

  @override
  void dispose() {
    progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_EditorInitial>(
      future: initial,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
              appBar: AppBar(title: const Text('Create surplus listing')),
              body: Center(child: Text(firebaseMessage(snapshot.error!))));
        }
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final data = snapshot.data!;
        return ListingEditorForm(
            initial: data.model,
            savedDraftData: data.savedData,
            initialPhotoBytes: data.bytes,
            recoveredPhoto: data.recovered,
            initialNotice: data.notice,
            business: widget.business,
            service: widget.service,
            editing: editing,
            resumedDraft: widget.draftData != null,
            duplicate: widget.duplicate,
            initialStock: widget.initial?['stock'] as int?,
            progress: progress,
            onSaveDraft: save,
            onPublish: publish,
            onPickPhoto: pick,
            onRemovePhoto: () =>
                picker.clearRecovery(uid: uid, draftId: editorId),
            onFinished: (published) => Navigator.pop(context, published));
      });
}

class _EditorInitial {
  const _EditorInitial(
      this.model, this.savedData, this.bytes, this.recovered, this.notice);
  final ListingEditorModel model;
  final Map<String, dynamic> savedData;
  final Uint8List? bytes;
  final bool recovered;
  final String? notice;
}

/// Stateful UI with injectable actions, shared by production and widget tests.
class ListingEditorForm extends StatefulWidget {
  const ListingEditorForm(
      {super.key,
      required this.initial,
      required this.business,
      required this.onSaveDraft,
      required this.onPublish,
      this.onPickPhoto,
      this.onRemovePhoto,
      this.onPickTime,
      this.onFinished,
      this.service,
      this.initialStock,
      this.editing = false,
      this.resumedDraft = false,
      this.duplicate = false,
      this.initialPhotoBytes,
      this.savedDraftData,
      this.recoveredPhoto = false,
      this.initialNotice,
      this.progress});
  final ListingEditorModel initial;
  final Map<String, dynamic> business;
  final EditorSaveDraft onSaveDraft;
  final EditorPublish onPublish;
  final EditorPickPhoto? onPickPhoto;
  final Future<void> Function()? onRemovePhoto;
  final EditorPickTime? onPickTime;
  final ValueChanged<bool>? onFinished;
  final FoodieService? service;
  final int? initialStock;
  final bool editing, resumedDraft, duplicate, recoveredPhoto;
  final Uint8List? initialPhotoBytes;
  final Map<String, dynamic>? savedDraftData;
  final String? initialNotice;
  final ValueListenable<String?>? progress;

  @override
  State<ListingEditorForm> createState() => _ListingEditorFormState();
}

class _ListingEditorFormState extends State<ListingEditorForm> {
  late final model = widget.initial.copy();
  late String savedFingerprint = widget.savedDraftData == null
      ? model.fingerprint
      : ListingEditorModel.fromDraft(widget.savedDraftData!).fingerprint;
  final controllers = <String, TextEditingController>{};
  final scroll = ScrollController();
  final previewLocation = PilotLocation();
  Map<String, String> errors = {};
  Uint8List? photoBytes;
  int step = 0;
  int? expectedStock;
  bool busy = false, allowPop = false, stockConfirmed = false;
  String? failure, notice, phase;

  bool get dirty => model.fingerprint != savedFingerprint;
  static const titles = [
    'Food details',
    'Pricing & quantity',
    'Pickup & publish'
  ];

  @override
  void initState() {
    super.initState();
    for (final entry in {
      'title': model.title,
      'description': model.description,
      'foodDescription': model.foodDescription,
      'ingredients': model.ingredients,
      'allergens': model.allergens,
      'pickupInstructions': model.pickupInstructions,
      'priceText': model.priceText,
      'originalPriceText': model.originalPriceText,
      'quantityText': model.quantityText,
    }.entries) {
      controllers[entry.key] = TextEditingController(text: entry.value);
    }
    photoBytes = widget.initialPhotoBytes;
    expectedStock = widget.initialStock;
    notice = widget.recoveredPhoto
        ? 'Your photo was recovered. Review it before saving or publishing.'
        : widget.initialNotice;
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    scroll.dispose();
    previewLocation.dispose();
    super.dispose();
  }

  void change(String key, String value) {
    switch (key) {
      case 'title':
        model.title = value;
      case 'description':
        model.description = value;
      case 'foodDescription':
        model.foodDescription = value;
      case 'ingredients':
        model.ingredients = value;
      case 'allergens':
        model.allergens = value;
      case 'pickupInstructions':
        model.pickupInstructions = value;
      case 'priceText':
        model.priceText = value;
      case 'originalPriceText':
        model.originalPriceText = value;
      case 'quantityText':
        model.quantityText = value;
        stockConfirmed = false;
    }
    setState(() {
      errors.remove(key);
      if (key == 'originalPriceText') errors.remove('priceText');
      failure = null;
    });
  }

  bool get needsStockReview =>
      widget.editing &&
      widget.resumedDraft &&
      listingQuantity(model.quantityText, allowZero: true) !=
          widget.initialStock;

  bool validate(int value) {
    final found = model.validateStep(value, editing: widget.editing);
    if (value == 1 && needsStockReview && !stockConfirmed) {
      found['quantityText'] =
          'Review and confirm the available quantity below.';
    }
    setState(() => errors = found);
    return found.isEmpty;
  }

  Future<void> move(int value) async {
    if (busy) return;
    if (value > step && !validate(step)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      step = value;
      errors = {};
      failure = null;
    });
    if (scroll.hasClients) {
      await scroll.animateTo(0,
          duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    }
  }

  bool validateAll() {
    for (var value = 0; value < 3; value++) {
      if (!validate(value)) {
        setState(() => step = value);
        if (scroll.hasClients) scroll.jumpTo(0);
        return false;
      }
    }
    return true;
  }

  void finished(bool published) {
    setState(() => allowPop = true);
    if (widget.onFinished != null) {
      widget.onFinished!(published);
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context, published);
    }
  }

  Future<bool> saveDraft({bool leave = false}) async {
    if (busy) return false;
    setState(() {
      busy = true;
      phase = 'Saving your draft…';
      failure = null;
    });
    try {
      await widget.onSaveDraft(model.copy(), photoBytes);
      if (!mounted) return false;
      setState(() {
        savedFingerprint = model.fingerprint;
        notice = 'Draft saved. Resume it from your vendor dashboard.';
      });
      if (leave) finished(false);
      return true;
    } catch (error) {
      if (mounted) setState(() => failure = firebaseMessage(error));
      return false;
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          phase = null;
        });
      }
    }
  }

  Future<void> requestLeave() async {
    if (busy) return;
    if (!dirty) {
      finished(false);
      return;
    }
    final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Leave this listing?'),
                content:
                    const Text('Save a draft to keep your latest changes.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, 'keep'),
                      child: const Text('Keep editing')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, 'leave'),
                      child: const Text('Leave without saving')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, 'save'),
                      child: const Text('Save draft & leave')),
                ]));
    if (!mounted || action == null || action == 'keep') return;
    if (action == 'save') {
      await saveDraft(leave: true);
    } else {
      finished(false);
    }
  }

  Future<void> pickPhoto(ImageSource source) async {
    if (busy || widget.onPickPhoto == null) return;
    setState(() {
      busy = true;
      phase = 'Saving before opening photos…';
      failure = null;
    });
    try {
      // Persist every field before the native activity can suspend this app.
      await widget.onSaveDraft(model.copy(), photoBytes);
      if (!mounted) return;
      setState(() {
        savedFingerprint = model.fingerprint;
        phase = 'Preparing food photo…';
      });
      final selection = await widget.onPickPhoto!(source);
      if (!mounted || selection == null) return;
      setState(() {
        model.imageId = selection.id;
        photoBytes = selection.photo.bytes;
        notice = 'Food photo ready. It will upload when you save or publish.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => failure = error is FoodPhotoException
            ? error.message
            : firebaseMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          phase = null;
        });
      }
    }
  }

  Future<void> useIllustrative({int? index}) async {
    if (busy) return;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await widget.onRemovePhoto?.call();
      if (!mounted) return;
      setState(() {
        photoBytes = null;
        model.imageId = null;
        if (index != null) model.imageKey = 'photo-$index';
        notice = 'Illustrative image selected. Students will see it labelled.';
      });
    } catch (error) {
      if (mounted) setState(() => failure = firebaseMessage(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> publish() async {
    if (busy || !validateAll()) return;
    setState(() {
      busy = true;
      phase = widget.editing ? 'Saving changes…' : 'Publishing your food…';
      failure = null;
    });
    try {
      await widget.onPublish(model.copy(), photoBytes, expectedStock);
      if (mounted) {
        savedFingerprint = model.fingerprint;
        finished(true);
      }
    } on ListingStockChanged catch (error) {
      if (mounted) {
        setState(() {
          expectedStock = error.currentStock;
          failure =
              'Stock changed while you were editing. Current available stock: ${error.currentStock}. Your entered quantity is kept. Review it and publish again to confirm.';
          step = 1;
        });
      }
    } catch (error) {
      if (mounted) setState(() => failure = firebaseMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          phase = null;
        });
      }
    }
  }

  Future<void> pickTime(bool start) async {
    if (busy) return;
    final millis = start ? model.pickupStart : model.pickupEnd;
    final current =
        millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
    DateTime? chosen;
    if (widget.onPickTime != null) {
      chosen = await widget.onPickTime!(start, current);
    } else {
      final now = DateTime.now();
      final first = DateTime(now.year, now.month, now.day);
      final last = first.add(const Duration(days: 30));
      final suggestion = current ?? now.add(Duration(hours: start ? 0 : 2));
      final initial = suggestion.isBefore(first)
          ? first
          : suggestion.isAfter(last)
              ? last
              : suggestion;
      final day = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: first,
          lastDate: last);
      if (day == null || !mounted) return;
      final time = await showTimePicker(
          context: context, initialTime: TimeOfDay.fromDateTime(suggestion));
      if (time == null || !mounted) return;
      chosen = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    }
    if (!mounted || chosen == null) return;
    setState(() {
      if (start) {
        model.pickupStart = chosen!.millisecondsSinceEpoch;
      } else {
        model.pickupEnd = chosen!.millisecondsSinceEpoch;
      }
      errors.remove(start ? 'pickupStart' : 'pickupEnd');
      failure = null;
    });
  }

  Widget textField(String key, String label, int max,
          {int lines = 1, String? helper, TextInputType? keyboard}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextField(
              key: ValueKey('listing-$key'),
              controller: controllers[key],
              enabled: !busy,
              maxLength: max,
              minLines: lines,
              maxLines: lines == 1 ? 1 : lines + 2,
              keyboardType: keyboard ??
                  (lines > 1 ? TextInputType.multiline : TextInputType.text),
              textCapitalization: keyboard == null
                  ? TextCapitalization.sentences
                  : TextCapitalization.none,
              onChanged: (value) => change(key, value),
              decoration: InputDecoration(
                  labelText: label,
                  helperText: helper,
                  helperMaxLines: 3,
                  errorText: errors[key],
                  errorMaxLines: 3,
                  counterText: keyboard == null ? null : '')));

  Widget card(Widget child, {EdgeInsets padding = const EdgeInsets.all(16)}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFE7ECE3))),
              child: Padding(padding: padding, child: child)));

  Widget photo({double height = 154}) => ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
          height: height,
          width: double.infinity,
          child: ListingFoodPhoto(
              service: widget.service,
              listing: {
                'imageKey': model.imageKey,
                if (model.imageId != null) 'imageId': model.imageId
              },
              bytes: photoBytes)));

  Widget foodDetails() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        card(Column(children: [
          textField('title', 'Food name *', 100,
              helper: 'A clear name helps students find your food.'),
          DropdownButtonFormField<String>(
              key: const ValueKey('listing-category'),
              initialValue: model.category,
              decoration: InputDecoration(
                  labelText: 'Food category *', errorText: errors['category']),
              items: listingCategories
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: busy
                  ? null
                  : (value) => setState(() {
                        model.category = value!;
                        errors.remove('category');
                        failure = null;
                      })),
          const SizedBox(height: 18),
          textField('description', 'What is included? *', 1000,
              lines: 2,
              helper:
                  'Describe the contents and portion size. Surprise bags may vary.'),
          ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Add a food description',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text('Optional, if different from the contents',
                  style: TextStyle(fontSize: 11)),
              children: [
                textField('foodDescription', 'Food description', 1000, lines: 2)
              ]),
        ])),
        card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Food photo',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
              'Show today’s food or keep a clearly labelled illustrative image.',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 12),
          photo(),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 6, children: [
            OutlinedButton.icon(
                onPressed: busy || widget.onPickPhoto == null
                    ? null
                    : () => pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Camera')),
            OutlinedButton.icon(
                onPressed: busy || widget.onPickPhoto == null
                    ? null
                    : () => pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Gallery')),
            if (model.imageId != null || photoBytes != null)
              TextButton.icon(
                  onPressed: busy ? null : () => useIllustrative(),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Remove photo')),
          ]),
          ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Illustrative image options',
                  style: TextStyle(fontSize: 13)),
              children: [
                SizedBox(
                    height: 80,
                    child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: 4,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, index) => Semantics(
                            button: true,
                            selected: model.imageId == null &&
                                model.imageKey == 'photo-$index',
                            label: 'Illustrative image ${index + 1}',
                            child: InkWell(
                                key: ValueKey('listing-preset-$index'),
                                onTap: busy
                                    ? null
                                    : () => useIllustrative(index: index),
                                child: Container(
                                    width: 90,
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            width: 2,
                                            color: model.imageId == null &&
                                                    model.imageKey ==
                                                        'photo-$index'
                                                ? managementGreen
                                                : const Color(0xFFE3EAE0))),
                                    child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: ReferenceFoodPhoto(
                                            index: index)))))))
              ]),
        ])),
        card(ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Ingredients & dietary details',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            subtitle: const Text('Optional information for safer pickups',
                style: TextStyle(fontSize: 11)),
            children: [
              textField('ingredients', 'Ingredients', 500, lines: 2),
              textField('allergens', 'Allergen information', 500,
                  lines: 2,
                  helper:
                      'List known allergens and possible cross-contact. Do not guess.'),
              Wrap(
                  spacing: 6,
                  children: listingDietaryTags
                      .map((tag) => FilterChip(
                          label: Text(tag),
                          selected: model.dietaryTags.contains(tag),
                          onSelected: busy
                              ? null
                              : (selected) => setState(() {
                                    if (selected) {
                                      model.dietaryTags.add(tag);
                                    } else {
                                      model.dietaryTags.remove(tag);
                                    }
                                    errors.remove('dietaryTags');
                                    failure = null;
                                  })))
                      .toList()),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                  initialValue: model.halalStatus,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Halal status'),
                  items: const [
                    DropdownMenuItem(
                        value: 'not_declared', child: Text('Not declared')),
                    DropdownMenuItem(
                        value: 'vendor_declared',
                        child: Text('Vendor declared halal'))
                  ],
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                            model.halalStatus = value!;
                            failure = null;
                          })),
              const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 12),
                  child: Text(
                      'FoodieNoms does not verify halal certification. Select a declaration only if you can support it.',
                      style: TextStyle(fontSize: 11, color: Colors.black54))),
              if (model.dietary.trim().isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('Existing dietary note: ${model.dietary}',
                        style: const TextStyle(fontSize: 12))),
            ])),
      ]);

  Widget pricing() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        card(Column(children: [
          textField('originalPriceText', 'Original price (RM) *', 12,
              keyboard: const TextInputType.numberWithOptions(decimal: true)),
          textField('priceText', 'Student price (RM) *', 12,
              keyboard: const TextInputType.numberWithOptions(decimal: true)),
          textField('quantityText', 'Available quantity *', 5,
              keyboard: TextInputType.number,
              helper: widget.editing
                  ? 'Use 0 for sold out. Existing reservations remain unchanged.'
                  : 'How many portions can students reserve?'),
          Row(children: [
            OutlinedButton(
                onPressed: busy ? null : () => adjustQuantity(-1),
                child: const Icon(Icons.remove, size: 18)),
            const SizedBox(width: 10),
            OutlinedButton(
                onPressed: busy ? null : () => adjustQuantity(1),
                child: const Icon(Icons.add, size: 18)),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Adjust portions',
                    style: TextStyle(fontSize: 12, color: Colors.black54))),
          ]),
          if (widget.editing && widget.initialStock != null)
            Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        'Available stock when opened: ${expectedStock ?? widget.initialStock}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)))),
          if (needsStockReview)
            CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: stockConfirmed,
                onChanged: busy
                    ? null
                    : (value) => setState(() {
                          stockConfirmed = value == true;
                          errors.remove('quantityText');
                        }),
                title: Text(
                    'Use ${model.quantityText} as the available quantity after reviewing current stock.',
                    style: const TextStyle(fontSize: 12))),
        ])),
        Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: managementGreen,
                borderRadius: BorderRadius.circular(20)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('A better deal for students',
                  style: TextStyle(color: Color(0xFFBED8C6), fontSize: 12)),
              const SizedBox(height: 12),
              Text(
                  model.studentCents == null
                      ? 'Enter your student price'
                      : listingMoney(model.studentCents!),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 29,
                      fontWeight: FontWeight.w800)),
              if (model.savingsCents != null) ...[
                const SizedBox(height: 10),
                Text(
                    '${model.discountPercent == 0 ? '<1' : model.discountPercent}% OFF · Students save ${listingMoney(model.savingsCents!)}',
                    style: const TextStyle(
                        color: Color(0xFFD9EDC7),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ] else
                const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                        'Set a student price below your original price to see savings.',
                        style:
                            TextStyle(color: Color(0xFFBED8C6), fontSize: 12))),
            ])),
        const SizedBox(height: 16),
      ]);

  void adjustQuantity(int delta) {
    final old = int.tryParse(model.quantityText) ?? 0;
    final next = (old + delta).clamp(widget.editing ? 0 : 1, 10000);
    controllers['quantityText']!.text = '$next';
    change('quantityText', '$next');
  }

  String dateTimeLabel(int? millis) {
    if (millis == null) return 'Choose date and time';
    final value = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${value.day}/${value.month}/${value.year} · ${TimeOfDay.fromDateTime(value).format(context)}';
  }

  Widget pickup() {
    final pin = ShopMapPin.fromData('pickup-shop', widget.business);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.storefront_outlined, size: 19, color: managementGreen),
          SizedBox(width: 8),
          Expanded(
              child: Text('Registered pickup shop',
                  style: TextStyle(fontSize: 12, color: Colors.black54)))
        ]),
        const SizedBox(height: 10),
        Text(widget.business['businessName'] as String? ?? '',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 4),
        Text(widget.business['address'] as String? ?? '',
            style: const TextStyle(fontSize: 13)),
        if (pin != null)
          ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title:
                  const Text('View pickup map', style: TextStyle(fontSize: 13)),
              children: [
                IgnorePointer(
                    child: LiveLocationMap(
                        location: previewLocation,
                        shops: [pin],
                        focusShop: pin,
                        height: 200)),
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                        'Map preview. Update your business profile to change the shop location.',
                        style: TextStyle(fontSize: 11, color: Colors.black54)))
              ]),
      ])),
      card(Column(children: [
        SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pickup starts now',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            subtitle: const Text('Start time refreshes when you publish.',
                style: TextStyle(fontSize: 11)),
            value: model.startsNow,
            onChanged: busy
                ? null
                : (value) => setState(() {
                      model.startsNow = value;
                      if (value) {
                        model.pickupStart =
                            DateTime.now().millisecondsSinceEpoch;
                      }
                      errors.remove('pickupStart');
                      errors.remove('pickupEnd');
                      failure = null;
                    })),
        ListTile(
            key: const ValueKey('listing-pickupStart'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined, color: managementGreen),
            title: const Text('Pickup starts', style: TextStyle(fontSize: 13)),
            subtitle: Text(
                model.startsNow
                    ? 'Today · when you publish'
                    : dateTimeLabel(model.pickupStart),
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            trailing: model.startsNow ? null : const Icon(Icons.chevron_right),
            onTap: busy || model.startsNow ? null : () => pickTime(true)),
        if (errors['pickupStart'] != null) inlineError(errors['pickupStart']!),
        const Divider(height: 12),
        ListTile(
            key: const ValueKey('listing-pickupEnd'),
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.access_time_rounded, color: managementGreen),
            title: const Text('Pickup ends', style: TextStyle(fontSize: 13)),
            subtitle: Text(dateTimeLabel(model.pickupEnd),
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            trailing: const Icon(Icons.chevron_right),
            onTap: busy ? null : () => pickTime(false)),
        if (errors['pickupEnd'] != null) inlineError(errors['pickupEnd']!),
        const SizedBox(height: 10),
        const Text(
            'Times use this device’s local timezone. For overnight pickup, choose the next day as the end date.',
            style: TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 18),
        textField('pickupInstructions', 'Pickup instructions (optional)', 500,
            lines: 2,
            helper:
                'For example: collect at the side counter and show your pickup code.'),
      ])),
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Ready for students',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(model.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
            '${listingMoney(model.studentCents ?? 0)} · ${model.quantityText} available',
            style: const TextStyle(
                color: managementGreen, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
            model.startsNow
                ? 'Pickup starts when you publish.'
                : 'Starts ${dateTimeLabel(model.pickupStart)}',
            style: const TextStyle(fontSize: 12)),
        Text('Ends ${dateTimeLabel(model.pickupEnd)}',
            style: const TextStyle(fontSize: 12)),
      ])),
    ]);
  }

  Widget inlineError(String text) => Align(
      alignment: Alignment.centerLeft,
      child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(text,
              style: const TextStyle(color: Color(0xFFAF3F31), fontSize: 12))));

  Future<void> preview() async {
    if (busy || !validateAll()) return;
    final data = model.toListingData(
        editing: widget.editing,
        initialStock: widget.initialStock,
        expectedStock: expectedStock);
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: managementCream,
        builder: (context) => SafeArea(
            child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .82,
                child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      const Text('Student preview',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: managementInk)),
                      const SizedBox(height: 6),
                      const Text('Check your food details before publishing.',
                          style:
                              TextStyle(fontSize: 12, color: Colors.black54)),
                      const SizedBox(height: 18),
                      StudentDealTile(
                          title: model.title,
                          price: listingMoney(model.studentCents!),
                          original: listingMoney(model.originalCents!),
                          subtitle: '${model.quantityText} available',
                          emoji: '🍱',
                          preview: true,
                          onTap: () {},
                          photoWidget: ListingFoodPhoto(
                              service: widget.service,
                              listing: data,
                              bytes: photoBytes)),
                      Text(widget.business['businessName'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                          'Students save ${listingMoney(model.savingsCents!)} · ${model.discountPercent == 0 ? '<1' : model.discountPercent}% OFF',
                          style: const TextStyle(
                              color: managementGreen,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      Text(model.description),
                      if (model.foodDescription.trim().isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(model.foodDescription)),
                      const SizedBox(height: 18),
                      Text('Pickup ${friendlyPickupWindow(data)}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(widget.business['address'] as String? ?? ''),
                      if (model.pickupInstructions.trim().isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(model.pickupInstructions)),
                      const SizedBox(height: 18),
                      const Text('Ingredients & allergens',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      Text(model.ingredients.trim().isEmpty
                          ? 'Ingredients not declared.'
                          : model.ingredients),
                      Text(model.allergens.trim().isEmpty
                          ? 'Allergens not declared. Ask the vendor before consuming.'
                          : 'Allergens: ${model.allergens}'),
                      if (model.dietaryTags.isNotEmpty)
                        Text(
                            'Vendor declares: ${model.dietaryTags.join(', ')}'),
                      Text(model.halalStatus == 'vendor_declared'
                          ? 'Halal: vendor declared. Certification is not verified.'
                          : 'Halal status not declared.'),
                      const SizedBox(height: 22),
                      FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Back to listing')),
                    ]))));
  }

  Widget footer(String? progress) => Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE6ECE1)))),
      child: SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (failure != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Semantics(
                          liveRegion: true,
                          child: Text(failure!,
                              style: const TextStyle(
                                  color: Color(0xFFAF3F31), fontSize: 12)))),
                SizedBox(
                    width: double.infinity,
                    child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        children: [
                          TextButton.icon(
                              onPressed: busy ? null : () => saveDraft(),
                              icon: const Icon(Icons.bookmark_border_rounded,
                                  size: 17),
                              label: const Text('Save draft')),
                          if (step == 2)
                            TextButton.icon(
                                onPressed: busy ? null : preview,
                                icon: const Icon(Icons.visibility_outlined,
                                    size: 17),
                                label: const Text('Preview'))
                          else
                            Text('Step ${step + 1} of 3',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                        ])),
                Row(children: [
                  if (step > 0) ...[
                    OutlinedButton(
                        onPressed: busy ? null : () => move(step - 1),
                        child: const Text('Back')),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                      child: FilledButton(
                          key: const ValueKey('listing-primary-action'),
                          onPressed: busy
                              ? null
                              : step < 2
                                  ? () => move(step + 1)
                                  : publish,
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              backgroundColor: managementGreen),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (busy) ...[
                                  const SizedBox(
                                      width: 17,
                                      height: 17,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                  const SizedBox(width: 8)
                                ],
                                Flexible(
                                    child: Text(
                                        busy
                                            ? progress ?? phase ?? 'Saving…'
                                            : step < 2
                                                ? 'Continue'
                                                : widget.editing
                                                    ? 'Save changes'
                                                    : 'Publish listing',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis)),
                                if (!busy && step < 2) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded,
                                      size: 18)
                                ],
                              ]))),
                ]),
              ]))));

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: allowPop || (!dirty && !busy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) requestLeave();
      },
      child: Scaffold(
          backgroundColor: managementCream,
          appBar: AppBar(
              backgroundColor: managementCream,
              foregroundColor: managementInk,
              leading: IconButton(
                  tooltip: step > 0 ? 'Previous step' : 'Leave listing',
                  onPressed: busy
                      ? null
                      : step > 0
                          ? () => move(step - 1)
                          : requestLeave,
                  icon: const Icon(Icons.arrow_back_rounded)),
              title: Text(
                  widget.editing
                      ? 'Edit listing'
                      : widget.duplicate
                          ? 'List again'
                          : 'Create surplus listing',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700))),
          body: Theme(
              data: Theme.of(context).copyWith(
                  inputDecorationTheme: InputDecorationTheme(
                      filled: true,
                      fillColor: const Color(0xFFF8FAF5),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 14),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFDFE7DA))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFDFE7DA))))),
              child: SafeArea(
                  bottom: false,
                  child: Column(children: [
                    Expanded(
                        child: ListView(
                            controller: scroll,
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                            children: [
                          Row(
                              children: List.generate(
                                  3,
                                  (index) => Expanded(
                                      child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 180),
                                          height: 4,
                                          margin: EdgeInsets.only(
                                              right: index == 2 ? 0 : 6),
                                          decoration: BoxDecoration(
                                              color: index <= step
                                                  ? managementGreen
                                                  : const Color(0xFFE0E8DA),
                                              borderRadius:
                                                  BorderRadius.circular(4)))))),
                          const SizedBox(height: 20),
                          Text(titles[step],
                              style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: managementInk)),
                          const SizedBox(height: 6),
                          Text(
                              step == 0
                                  ? 'Make your surplus food easy to discover.'
                                  : step == 1
                                      ? 'Set a fair deal and the portions you have left.'
                                      : 'Confirm the pickup details and make it live.',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                          if (widget.duplicate && step == 0)
                            const Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: Text(
                                    'Food details are copied. Review fresh prices, quantity and pickup times.',
                                    style: TextStyle(
                                        fontSize: 12, color: managementGreen))),
                          if (notice != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(notice!,
                                    style: const TextStyle(
                                        fontSize: 12, color: managementGreen))),
                          const SizedBox(height: 20),
                          AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: KeyedSubtree(
                                  key: ValueKey(step),
                                  child: step == 0
                                      ? foodDetails()
                                      : step == 1
                                          ? pricing()
                                          : pickup())),
                        ])),
                    if (widget.progress == null)
                      footer(null)
                    else
                      ValueListenableBuilder<String?>(
                          valueListenable: widget.progress!,
                          builder: (_, value, __) => footer(value)),
                  ])))));
}
