import 'package:flutter/material.dart';

class StatsWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      buildButton(text: 'مباراة', value: 331),
      buildDivider(),
      buildButton(text: 'اهداف', value: 291),
      buildDivider(),
      buildButton(text: 'صناعة', value: 59),
    ],
  );

  Widget buildDivider() => Container(height: 24, child: VerticalDivider());

  Widget buildButton({required String text, required int value}) =>
      MaterialButton(
        padding: EdgeInsets.symmetric(vertical: 4),
        onPressed: () {},
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Text(
              '$value',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 2),
            Text(text, style: TextStyle(fontSize: 16)),
          ],
        ),
      );
}