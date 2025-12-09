// lib/widgets/message_bubble.dart
import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.isMe,
    required this.text,
    required this.timeLabel,
    this.onLongPress,
  });

  final bool isMe;
  final String text;
  final String timeLabel;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    const bleu = Color(0xFF113CFC);
    const gris = Color(0xFFF3F5FA);

    final bg = isMe ? bleu : gris;
    final fg = isMe ? Colors.white : Colors.black87;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            // largeur max ~ 78% de l'écran, mais la bulle reste
            // au plus petit possible (pas de minWidth)
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Container(
            margin: EdgeInsets.only(
              top: 4,
              bottom: 4,
              left: isMe ? 40 : 12,
              right: isMe ? 12 : 40,
            ),
            padding: const EdgeInsets.fromLTRB(14, 8, 10, 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 8),
                bottomRight: Radius.circular(isMe ? 8 : 18),
              ),
              boxShadow: [
                if (isMe)
                  BoxShadow(
                    color: Colors.blue.shade100,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
              ],
            ),
            // Stack pour avoir l'heure en bas à droite *dans* la bulle,
            // sans rajouter une ligne sous le texte → pas d'espace vertical
            child: Stack(
              children: [
                // texte avec un padding à droite pour laisser la place à l'heure
                Padding(
                  padding: const EdgeInsets.only(right: 46),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: fg,
                      fontSize: 15,
                      height: 1.25,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: fg.withOpacity(isMe ? 0.8 : 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
