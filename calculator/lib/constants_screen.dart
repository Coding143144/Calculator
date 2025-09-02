import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:calculator/constants_manager.dart';

class ConstantsScreen extends StatefulWidget {
  const ConstantsScreen({super.key});

  @override
  State<ConstantsScreen> createState() => _ConstantsScreenState();
}

class _ConstantsScreenState extends State<ConstantsScreen> {
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _constantsManager = ConstantsManager.instance;

  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _constantsManager.init();
  }

  Future<void> _addConstant() async {
    if (_formKey.currentState!.validate()) {
      await _constantsManager.addConstant(
        _nameController.text.trim(),
        double.parse(_valueController.text.trim()),
      );
      setState(() {});
      _nameController.clear();
      _valueController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Constant added')),
      );
    }
  }

  Future<void> _removeConstant(String name) async {
    await _constantsManager.removeConstant(name);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Removed constant $name')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom Constants')),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Name'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter a name';
                            }
                            if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$')
                                .hasMatch(value)) {
                              return 'Invalid name';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _valueController,
                          decoration:
                              const InputDecoration(labelText: 'Value'),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^[0-9]+(\.[0-9]*)?$')),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter a value';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Invalid number';
                            }
                            return null;
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addConstant,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _constantsManager.constants.isEmpty
                    ? const Center(child: Text('No constants added yet'))
                    : ListView(
                        children: _constantsManager.constants.entries.map(
                          (entry) {
                            return Dismissible(
                              key: Key(entry.key),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) => _removeConstant(entry.key),
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              child: ListTile(
                                title: Text(entry.key),
                                subtitle: Text(entry.value.toString()),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _removeConstant(entry.key),
                                ),
                              ),
                            );
                          },
                        ).toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
