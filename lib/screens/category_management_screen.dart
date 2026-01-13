import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/services/grading_category_service.dart';
import 'package:gradeflow/models/grading_category.dart';
import 'package:gradeflow/theme.dart';
import 'package:gradeflow/components/animated_glow_border.dart';
import 'package:uuid/uuid.dart';

class CategoryManagementScreen extends StatefulWidget {
  final String classId;

  const CategoryManagementScreen({super.key, required this.classId});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    await context.read<GradingCategoryService>().loadCategories(widget.classId);
  }

  Future<void> _showAddCategoryDialog() async {
    final nameController = TextEditingController();
    final weightController = TextEditingController();
    AggregationMethod selectedMethod = AggregationMethod.average;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Category Name'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: weightController,
                  decoration: const InputDecoration(labelText: 'Weight (%)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<AggregationMethod>(
                  value: selectedMethod,
                  decoration: const InputDecoration(labelText: 'Aggregation Method'),
                  items: AggregationMethod.values.map((method) {
                    return DropdownMenuItem(value: method, child: Text(method.displayName));
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedMethod = value!);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    
    if (result == true && mounted) {
      final weight = double.tryParse(weightController.text);
      if (weight == null || weight <= 0) {
        _showError('Invalid weight');
        return;
      }
      
      final now = DateTime.now();
      final category = GradingCategory(
        categoryId: const Uuid().v4(),
        classId: widget.classId,
        name: nameController.text,
        weightPercent: weight,
        aggregationMethod: selectedMethod,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      
      await context.read<GradingCategoryService>().addCategory(category);
      _showSuccess('Category added');
    }
  }

  Future<void> _showEditWeightDialog(GradingCategory category) async {
    final nameController = TextEditingController(text: category.name);
    final weightController = TextEditingController(text: category.weightPercent.toString());
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: weightController,
              decoration: const InputDecoration(labelText: 'Weight (%)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (result == true && mounted) {
      final weight = double.tryParse(weightController.text);
      if (weight != null && weight > 0) {
        final updated = category.copyWith(
          name: nameController.text.trim().isEmpty ? category.name : nameController.text.trim(),
          weightPercent: weight,
          updatedAt: DateTime.now(),
        );
        await context.read<GradingCategoryService>().updateCategory(updated);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final categoryService = context.watch<GradingCategoryService>();
    final totalWeight = categoryService.getTotalWeight(widget.classId);
    final isValid = categoryService.isWeightValid(widget.classId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grading Categories'),
      ),
      body: Column(
        children: [
          Container(
            padding: AppSpacing.paddingLg,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Weight:', style: context.textStyles.titleMedium),
                    Text('${totalWeight.toStringAsFixed(1)}% / 100%', style: context.textStyles.titleLarge?.bold.withColor(isValid ? LightModeColors.lightSuccess : LightModeColors.lightWarning)),
                  ],
                ),
                if (!isValid) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: AppSpacing.paddingMd,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Theme.of(context).colorScheme.onErrorContainer),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Category weights must total 100% (applied to the 40% process component)',
                            style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: () async {
                      await categoryService.autoFixWeights(widget.classId);
                      _showSuccess('Weights auto-balanced to 100%');
                    },
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Auto-Fix to 100%'),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: categoryService.categories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.category_outlined, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: AppSpacing.md),
                        Text('No categories yet', style: context.textStyles.titleLarge),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: AppSpacing.paddingMd,
                    itemCount: categoryService.categories.length,
                    itemBuilder: (context, index) {
                      final category = categoryService.categories[index];
                      return AnimatedGlowBorder(
                        child: Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              child: Text(
                                '${category.weightPercent.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(category.name),
                            subtitle: Text(category.aggregationMethod.displayName),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showEditWeightDialog(category),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete Category'),
                                        content: Text('Delete ${category.name}?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    
                                    if (confirm == true && mounted) {
                                      await categoryService.deleteCategory(category.categoryId);
                                      _showSuccess('Category deleted');
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCategoryDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
    );
  }
}
