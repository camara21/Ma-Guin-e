import 'package:flutter/material.dart';

class FiltreButtons extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final Function(int) onSelected;

  const FiltreButtons({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(options[index]),
              selected: selected,
              onSelected: (_) => onSelected(index),
              backgroundColor: Colors.grey[200],
              selectedColor: const Color(0xFFCE1126),
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.black,
              ),
            ),
          );
        },
      ),
    );
  }
}
