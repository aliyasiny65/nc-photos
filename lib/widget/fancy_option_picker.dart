import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class FancyOptionPickerItem {
  FancyOptionPickerItem({
    @required this.label,
    this.isSelected = false,
    this.onSelect,
  });

  String label;
  bool isSelected;
  VoidCallback onSelect;
}

/// A fancy looking dialog to pick an option
class FancyOptionPicker extends StatelessWidget {
  FancyOptionPicker({
    Key key,
    this.title,
    @required this.items,
  }) : super(key: key);

  @override
  build(BuildContext context) {
    return SimpleDialog(
      title: title != null ? Text(title) : null,
      children: items
          .map((e) => SimpleDialogOption(
                child: ListTile(
                  leading: Icon(
                    e.isSelected ? Icons.check : null,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    e.label,
                    style: e.isSelected
                        ? TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                  ),
                  onTap: e.isSelected ? null : e.onSelect,
                ),
              ))
          .toList(),
    );
  }

  final String title;
  final List<FancyOptionPickerItem> items;
}
