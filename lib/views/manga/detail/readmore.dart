import 'package:expandable_text/expandable_text.dart';
import 'package:flutter/material.dart';
import 'package:mangayomi/utils/media_query.dart';

class ReadMoreWidget extends StatefulWidget {
  const ReadMoreWidget({Key? key, required this.text, required this.onChanged})
      : super(key: key);
  final Function(bool) onChanged;
  final String text;

  @override
  ReadMoreWidgetState createState() => ReadMoreWidgetState();
}

class ReadMoreWidgetState extends State<ReadMoreWidget>
    with TickerProviderStateMixin {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            ExpandableText(
              animationDuration: const Duration(milliseconds: 500),
              onExpandedChanged: (ok) {
                setState(() => expanded = ok);
                widget.onChanged(ok);
              },
              expandOnTextTap: true,
              widget.text,
              expandText: '',
              maxLines: 3,
              expanded: false,
              onPrefixTap: () {
                setState(() => expanded = !expanded);
                widget.onChanged(expanded);
              },
              linkColor: Theme.of(context).scaffoldBackgroundColor,
              animation: true,
              collapseOnTextTap: true,
              prefixText: '',
            ),
            if (!expanded)
              Positioned(
                bottom: 0,
                right: 0,
                left: 0,
                child: Container(
                  width: mediaWidth(context, 1),
                  height: 20,
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context)
                            .scaffoldBackgroundColor
                            .withOpacity(0.2),
                        Theme.of(context).scaffoldBackgroundColor
                      ],
                      stops: const [0, .9],
                    ),
                  ),
                  child: const Icon(Icons.keyboard_arrow_down_sharp),
                ),
              ),
          ],
        ),
        if (expanded)
          SizedBox(
            width: mediaWidth(context, 1),
            height: 20,
            child: const Icon(Icons.keyboard_arrow_up_sharp),
          )
      ],
    );
  }
}
