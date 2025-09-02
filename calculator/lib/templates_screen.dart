import 'package:flutter/material.dart';
import 'package:calculator/template_manager.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final TemplateManager _templateManager = TemplateManager();

  @override
  void initState() {
    super.initState();
    _templateManager.loadTemplates().then((_) => setState(() {}));
  }

  Future<void> _showAddDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AddEditTemplateDialog(isEdit: false),
    );
    if (saved == true) setState(() {});
  }

  Future<void> _showEditDialog(String existingName, String existingExpression) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AddEditTemplateDialog(
        isEdit: true,
        initialName: existingName,
        initialExpression: existingExpression,
      ),
    );
    if (saved == true) setState(() {});
  }

  Future<void> _confirmDelete(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Delete "$name"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );

    if (ok == true) {
      await _templateManager.deleteUserTemplate(name);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _templateManager.templates.entries.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Formula Templates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: "Search Formula",
            onPressed: () async {
              final selected = await showSearch(
                context: context,
                delegate: FormulaSearchDelegate(_templateManager),
              );
              if (selected != null && selected.isNotEmpty) {
                Navigator.pop(context, selected);
              }
            },
          )
        ],
      ),
      body: ListView(
        children: entries.map((category) {
          final isUserCategory = category.key == 'User Templates';
          final templates = category.value.entries.toList();
          return ExpansionTile(
            leading: const Icon(Icons.book),
            title: Text(
              category.key,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            children: templates.map((template) {
              final title = template.key;
              final expr = template.value;
              return ListTile(
                title: Text(title),
                subtitle: Text(expr, style: const TextStyle(color: Colors.blueGrey)),
                trailing: isUserCategory
                    ? PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            await _showEditDialog(title, expr);
                          } else if (value == 'delete') {
                            await _confirmDelete(title);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      )
                    : const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // return the expression to caller
                  Navigator.pop(context, expr);
                },
              );
            }).toList(),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
        tooltip: 'Add custom formula',
      ),
    );
  }
}

/// Dialog used for both adding and editing user templates.
class AddEditTemplateDialog extends StatefulWidget {
  final bool isEdit;
  final String? initialName;
  final String? initialExpression;

  const AddEditTemplateDialog({
    super.key,
    required this.isEdit,
    this.initialName,
    this.initialExpression,
  });

  @override
  State<AddEditTemplateDialog> createState() => _AddEditTemplateDialogState();
}

class _AddEditTemplateDialogState extends State<AddEditTemplateDialog> {
  final _nameController = TextEditingController();
  final _exprController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final TemplateManager _manager = TemplateManager();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName ?? '';
    _exprController.text = widget.initialExpression ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _exprController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final expr = _exprController.text.trim();

    if (name.isEmpty || expr.isEmpty) {
      setState(() => _errorText = 'Both name and expression are required.');
      return;
    }

    final userMap = _manager.templates['User Templates'] ?? {};

    if (!widget.isEdit && userMap.containsKey(name)) {
      setState(() => _errorText = 'A template with that name already exists.');
      return;
    }

    if (widget.isEdit) {
      final oldName = widget.initialName!;
      await _manager.editUserTemplate(oldName, name, expr);
    } else {
      await _manager.addTemplate('User Templates', name, expr);
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEdit ? 'Edit Template' : 'Add Template'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Template name'),
            ),
            TextFormField(
              controller: _exprController,
              decoration: const InputDecoration(labelText: 'Expression'),
              minLines: 1,
              maxLines: 4,
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(_errorText!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

/// Simple search delegate that returns the selected expression string.
class FormulaSearchDelegate extends SearchDelegate<String> {
  final TemplateManager templateManager;

  FormulaSearchDelegate(this.templateManager);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = _searchFormulas(query);
    return _buildResultList(results);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final results = _searchFormulas(query);
    return _buildResultList(results);
  }

  List<MapEntry<String, String>> _searchFormulas(String q) {
    if (q.trim().isEmpty) return [];
    final qLower = q.toLowerCase();
    final all = templateManager.templates.values.expand((cat) => cat.entries);
    return all
        .where((e) => e.key.toLowerCase().contains(qLower) || e.value.toLowerCase().contains(qLower))
        .toList();
  }

  Widget _buildResultList(List<MapEntry<String, String>> results) {
    if (results.isEmpty) return const Center(child: Text('No formulas found'));
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final entry = results[index];
        return ListTile(
          title: Text(entry.key),
          subtitle: Text(entry.value),
          onTap: () => close(context, entry.value),
        );
      },
    );
  }
}
