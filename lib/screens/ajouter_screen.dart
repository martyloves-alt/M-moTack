import 'package:flutter/material.dart';

import '../engine.dart';
import '../models.dart';
import '../storage.dart';
import '../theme.dart';

class AjouterScreen extends StatefulWidget {
  final AppState appState;
  const AjouterScreen({super.key, required this.appState});

  @override
  State<AjouterScreen> createState() => _AjouterScreenState();
}

class _AjouterScreenState extends State<AjouterScreen> {
  final _frontController = TextEditingController();
  final _backController = TextEditingController();
  late String _selectedTagId;

  @override
  void initState() {
    super.initState();
    _selectedTagId = widget.appState.tags.first.id;
  }

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    super.dispose();
  }

  void _submit() {
    final front = _frontController.text.trim();
    if (front.isEmpty) return;

    final card = createFlashcard(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      front: front,
      back: _backController.text.trim(),
      tagId: _selectedTagId,
      now: DateTime.now(),
    );

    widget.appState.addCard(card);

    _frontController.clear();
    _backController.clear();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ajouté au carnet')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedTag = widget.appState.tags.firstWhere(
      (t) => t.id == _selectedTagId,
      orElse: () => widget.appState.tags.first,
    );

    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        elevation: 0,
        title: Text(
          'Ajouter un élément',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.paper, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MOT OU PHRASE', style: stampStyle(color: AppColors.soot.withValues(alpha: 0.6))),
                const SizedBox(height: 4),
                TextField(
                  controller: _frontController,
                  maxLength: 150,
                  onChanged: (_) => setState(() {}),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.soot, fontSize: 16),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: 'ex. Anasarque, ou une courte phrase...',
                    hintStyle: TextStyle(color: AppColors.soot.withValues(alpha: 0.4)),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_frontController.text.length}/150',
                    style: TextStyle(color: AppColors.soot.withValues(alpha: 0.4), fontSize: 10),
                  ),
                ),
                Divider(color: AppColors.soot.withValues(alpha: 0.1)),
                Text('DÉFINITION / NOTE (OPTIONNEL)', style: stampStyle(color: AppColors.soot.withValues(alpha: 0.6))),
                const SizedBox(height: 4),
                TextField(
                  controller: _backController,
                  style: TextStyle(color: AppColors.soot),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Un rappel du sens, si besoin',
                    hintStyle: TextStyle(color: AppColors.soot.withValues(alpha: 0.4)),
                  ),
                ),
                Divider(color: AppColors.soot.withValues(alpha: 0.1)),
                Text('ÉTIQUETTE', style: stampStyle(color: AppColors.soot.withValues(alpha: 0.6))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: widget.appState.tags.map((t) {
                    final selected = t.id == _selectedTagId;
                    return ChoiceChip(
                      label: Text(t.name),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedTagId = t.id),
                      selectedColor: AppColors.inkBlue,
                      backgroundColor: Colors.transparent,
                      side: BorderSide(color: selected ? AppColors.inkBlue : AppColors.soot.withValues(alpha: 0.2)),
                      labelStyle: TextStyle(color: selected ? AppColors.paper : AppColors.soot, fontSize: 11),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          if (_frontController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('APERÇU DE LA CARTE', style: stampStyle(color: AppColors.paperMuted)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    decoration: BoxDecoration(
                      color: AppColors.forTagColor(tagColorToString(selectedTag.color)),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _frontController.text,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.soot, fontSize: 15),
                        ),
                        if (_backController.text.isNotEmpty)
                          Text(
                            _backController.text,
                            style: TextStyle(color: AppColors.soot.withValues(alpha: 0.6), fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.inkBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _submit,
              child: const Text('Ajouter au carnet'),
            ),
          ),
        ],
      ),
    );
  }
}
