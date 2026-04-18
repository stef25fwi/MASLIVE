import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class BloomArtPhotoPicker extends StatefulWidget {
  const BloomArtPhotoPicker({
    super.key,
    required this.onChanged,
    this.initialFiles = const <XFile>[],
  });

  final List<XFile> initialFiles;
  final ValueChanged<List<XFile>> onChanged;

  @override
  State<BloomArtPhotoPicker> createState() => _BloomArtPhotoPickerState();
}

class _BloomArtPhotoPickerState extends State<BloomArtPhotoPicker> {
  final ImagePicker _picker = ImagePicker();
  late List<XFile> _files;

  @override
  void initState() {
    super.initState();
    _files = List<XFile>.from(widget.initialFiles);
  }

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 88, limit: 10);
    if (files.isEmpty) return;
    setState(() {
      _files = List<XFile>.from(files.take(10));
    });
    widget.onChanged(_files);
  }

  void _removeAt(int index) {
    setState(() {
      _files.removeAt(index);
    });
    widget.onChanged(_files);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: _pickImages,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Ajouter des photos'),
        ),
        const SizedBox(height: 12),
        if (_files.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8DED3)),
            ),
            child: const Text(
              'Ajoutez jusqu\'a 10 photos. Elles seront uploadees dans Firebase Storage au moment de la publication.',
              style: TextStyle(color: Color(0xFF6A645E)),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _files.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (BuildContext context, int index) {
              final file = _files[index];
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: kIsWeb
                        ? Image.network(file.path, fit: BoxFit.cover)
                        : Image.file(File(file.path), fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: InkWell(
                      onTap: () => _removeAt(index),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}