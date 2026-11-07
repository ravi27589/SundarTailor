import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/customer.dart';
import '../../data/repository/customer_repository.dart';
import '../../data/repository/order_repository.dart';
import '../../widgets/brand_title.dart';
import '../orders/take_order_screen.dart';

const _shirtMeasurementTemplate = 'SP SC 2.5 TP 1. 1FP';
const _trouserMeasurementTemplate = 'DLS 1.5 SP 2BCT 8R SELF HOOK';

class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.customer});

  final Customer? customer;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;
  late final TextEditingController _shirtMeasurementsController;
  late final TextEditingController _trouserMeasurementsController;
  late final TextEditingController _pajamaMeasurementsController;
  late final TextEditingController _suitMeasurementsController;
  late final TextEditingController _shortsMeasurementsController;
  late final TextEditingController _kurtaMeasurementsController;
  late final TextEditingController _safariMeasurementsController;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _nameController = TextEditingController(text: customer?.name ?? '');
    _phoneController = TextEditingController(text: customer?.phone ?? '');
    _notesController = TextEditingController(text: customer?.notes ?? '');
    _shirtMeasurementsController = TextEditingController(
      text: _measurementsText(
        customer?.shirtMeasurements ?? const {},
        template: _shirtMeasurementTemplate,
      ),
    );
    _trouserMeasurementsController = TextEditingController(
      text: _measurementsText(
        customer?.trouserMeasurements ?? const {},
        template: _trouserMeasurementTemplate,
      ),
    );
    _pajamaMeasurementsController = TextEditingController(
      text: _measurementsText(customer?.pajamaMeasurements ?? const {}),
    );
    _suitMeasurementsController = TextEditingController(
      text: _measurementsText(customer?.suitMeasurements ?? const {}),
    );
    _shortsMeasurementsController = TextEditingController(
      text: _measurementsText(customer?.shortsMeasurements ?? const {}),
    );
    _kurtaMeasurementsController = TextEditingController(
      text: _measurementsText(customer?.kurtaMeasurements ?? const {}),
    );
    _safariMeasurementsController = TextEditingController(
      text: _measurementsText(customer?.safariMeasurements ?? const {}),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    for (final controller in [
      _shirtMeasurementsController,
      _trouserMeasurementsController,
      _pajamaMeasurementsController,
      _suitMeasurementsController,
      _shortsMeasurementsController,
      _kurtaMeasurementsController,
      _safariMeasurementsController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.customer != null;

    return Scaffold(
      appBar: AppBar(
        title: BrandTitle(title: isEditing ? 'Edit Customer' : 'Add Customer'),
        actions: [
          if (widget.customer case final customer?)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _isSaving ? null : () => _takeOrder(customer),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Take Order'),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _save,
        icon: const Icon(Icons.save_outlined),
        label: Text(_isSaving ? 'Saving...' : 'Save Customer'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 800;
              final contentWidth =
                  constraints.maxWidth > 1160 ? 1160.0 : constraints.maxWidth;
              final horizontalPadding = wide ? 24.0 : 16.0;
              final formWidth = contentWidth - horizontalPadding * 2;

              return Center(
                child: SizedBox(
                  width: contentWidth,
                  child: ListView(
                    padding: EdgeInsets.all(horizontalPadding),
                    children: [
                      Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0877E8),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isEditing
                              ? 'Edit Customer  ·  ${widget.customer!.customerNumber}'
                              : 'Add New Customer',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _CustomerInformation(
                        wide: wide,
                        customerNumber: widget.customer?.customerNumber,
                        nameController: _nameController,
                        phoneController: _phoneController,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Measurements',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 16,
                        runSpacing: 14,
                        children: [
                          SizedBox(
                            width: _panelWidth(formWidth, wide),
                            child: _FreeformMeasurementSection(
                              title: 'Shirt',
                              controller: _shirtMeasurementsController,
                            ),
                          ),
                          _measurementPanel(
                            formWidth,
                            wide,
                            'Trouser',
                            _trouserMeasurementsController,
                          ),
                          _measurementPanel(
                            formWidth,
                            wide,
                            'Pajama',
                            _pajamaMeasurementsController,
                          ),
                          _measurementPanel(
                            formWidth,
                            wide,
                            'Suit',
                            _suitMeasurementsController,
                          ),
                          _measurementPanel(
                            formWidth,
                            wide,
                            'Shorts',
                            _shortsMeasurementsController,
                          ),
                          _measurementPanel(
                            formWidth,
                            wide,
                            'Kurta',
                            _kurtaMeasurementsController,
                          ),
                          _measurementPanel(
                            formWidth,
                            wide,
                            'Safari',
                            _safariMeasurementsController,
                          ),
                          SizedBox(
                            width: _panelWidth(formWidth, wide),
                            child: _NotesPanel(controller: _notesController),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  SizedBox _measurementPanel(
    double availableWidth,
    bool wide,
    String title,
    TextEditingController controller,
  ) {
    return SizedBox(
      width: _panelWidth(availableWidth, wide),
      child: _FreeformMeasurementSection(
        title: title,
        controller: controller,
      ),
    );
  }

  double _panelWidth(double availableWidth, bool wide) {
    if (!wide) {
      return availableWidth;
    }
    return (availableWidth - 16) / 2;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repository = await ref.read(customerRepositoryProvider.future);
      final customer = widget.customer;

      if (customer == null) {
        await repository.createCustomer(
          name: _nameController.text,
          phone: _phoneController.text,
          shirtMeasurements: _shirtMeasurementValue(),
          trouserMeasurements:
              _measurementValue(_trouserMeasurementsController),
          pajamaMeasurements: _measurementValue(_pajamaMeasurementsController),
          suitMeasurements: _measurementValue(_suitMeasurementsController),
          shortsMeasurements: _measurementValue(_shortsMeasurementsController),
          kurtaMeasurements: _measurementValue(_kurtaMeasurementsController),
          safariMeasurements: _measurementValue(_safariMeasurementsController),
          notes: _notesController.text,
        );
      } else {
        await repository.updateCustomer(
          customer.copyWith(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            shirtMeasurements: _shirtMeasurementValue(),
            trouserMeasurements:
                _measurementValue(_trouserMeasurementsController),
            pajamaMeasurements:
                _measurementValue(_pajamaMeasurementsController),
            suitMeasurements: _measurementValue(_suitMeasurementsController),
            shortsMeasurements:
                _measurementValue(_shortsMeasurementsController),
            kurtaMeasurements: _measurementValue(_kurtaMeasurementsController),
            safariMeasurements:
                _measurementValue(_safariMeasurementsController),
            notes: _notesController.text.trim(),
          ),
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save customer: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Map<String, String> _shirtMeasurementValue() {
    return _measurementValue(_shirtMeasurementsController);
  }

  Map<String, String> _measurementValue(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? const {} : {'measurements': value};
  }

  Future<void> _takeOrder(Customer customer) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TakeOrderScreen(customer: customer),
      ),
    );

    if (saved == true) {
      ref.invalidate(customerOrdersProvider(customer.id));
      ref.invalidate(ordersProvider);
    }
  }
}

String _measurementsText(
  Map<String, String> measurements, {
  String? template,
}) {
  final freeform = measurements['measurements'];
  final savedText = freeform ??
      measurements.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join('\n');

  if (template == null) {
    return savedText;
  }
  if (savedText.isEmpty) {
    return '$template\n';
  }
  if (savedText == template || savedText.startsWith('$template\n')) {
    return savedText;
  }
  return '$template\n$savedText';
}

class _FreeformMeasurementSection extends StatelessWidget {
  const _FreeformMeasurementSection({
    required this.title,
    required this.controller,
  });

  final String title;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD9DEE3)),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 40,
            color: const Color(0xFFF1F3F5),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter measurements, one per line',
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
              alignLabelWithHint: true,
            ),
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            minLines: 5,
            maxLines: 8,
          ),
        ],
      ),
    );
  }
}

class _CustomerInformation extends StatelessWidget {
  const _CustomerInformation({
    required this.wide,
    required this.customerNumber,
    required this.nameController,
    required this.phoneController,
  });

  final bool wide;
  final String? customerNumber;
  final TextEditingController nameController;
  final TextEditingController phoneController;

  @override
  Widget build(BuildContext context) {
    final fields = [
      if (customerNumber != null)
        _InfoField(
          label: 'Customer ID',
          child: InputDecorator(
            decoration: const InputDecoration(isDense: true),
            child: Text(customerNumber!),
          ),
        ),
      _InfoField(
        label: 'Name',
        child: TextFormField(
          controller: nameController,
          decoration: const InputDecoration(isDense: true),
          textCapitalization: TextCapitalization.words,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter the customer name'
              : null,
        ),
      ),
      _InfoField(
        label: 'Phone number',
        child: TextFormField(
          controller: phoneController,
          decoration: const InputDecoration(isDense: true),
          keyboardType: TextInputType.phone,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter the phone number'
              : null,
        ),
      ),
    ];

    if (!wide) {
      return Column(
        children: [
          for (final field in fields) ...[
            field,
            const SizedBox(height: 12),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < fields.length; index++) ...[
          if (index > 0) const SizedBox(width: 16),
          Expanded(child: fields[index]),
        ],
      ],
    );
  }
}

class _InfoField extends StatelessWidget {
  const _InfoField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        child,
      ],
    );
  }
}

class _NotesPanel extends StatelessWidget {
  const _NotesPanel({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD9DEE3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 40,
            color: const Color(0xFFF1F3F5),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: const Text(
              'Additional Measurements / Notes',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Customer preferences, fit notes, or other details',
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
            ),
            minLines: 3,
            maxLines: 5,
          ),
        ],
      ),
    );
  }
}
