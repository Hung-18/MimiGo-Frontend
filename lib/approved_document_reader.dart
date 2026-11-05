import 'package:flutter/material.dart';

import 'account_availability.dart';
import 'mimigo_design.dart';

/// A decision is returned only by an explicit action. Closing never accepts.
/// The owning screen must recheck its current version/hash after the await.
Future<bool?> readApprovedDocument(
  BuildContext context,
  ApprovedLegalDocument document,
) => !document.matches(document.versionId, document.contentHash)
    ? Future.value(null)
    : showDialog<bool>(
        context: context,
        builder: (_) => _DocumentReader(document),
      );

class ApprovedDocumentCard extends StatelessWidget {
  const ApprovedDocumentCard({
    super.key,
    required this.document,
    required this.readKey,
    required this.read,
    this.enabled = true,
  });
  final ApprovedLegalDocument document;
  final Key readKey;
  final VoidCallback read;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: MimiColors.sky,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(document.title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(
          document.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        TextButton.icon(
          key: readKey,
          onPressed: enabled ? read : null,
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('Đọc toàn bộ văn bản'),
        ),
      ],
    ),
  );
}

class _DocumentReader extends StatefulWidget {
  const _DocumentReader(this.document);
  final ApprovedLegalDocument document;
  @override
  State<_DocumentReader> createState() => _DocumentReaderState();
}

class _DocumentReaderState extends State<_DocumentReader> {
  bool chosen = false;
  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      widget.document.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('legalClose'),
                  tooltip: 'Đóng văn bản',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(
                    widget.document.body,
                    key: const Key('legalFullText'),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  CheckboxListTile(
                    key: const Key('legalExplicitChoice'),
                    value: chosen,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) =>
                        setState(() => chosen = value ?? false),
                    title: const Text('Tôi đã đọc và đồng ý với văn bản này.'),
                  ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        key: const Key('legalDisagree'),
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Không đồng ý'),
                      ),
                      FilledButton(
                        key: const Key('legalAgree'),
                        onPressed: chosen
                            ? () => Navigator.pop(context, true)
                            : null,
                        child: const Text('Đồng ý'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
