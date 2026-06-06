import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageGalleryViewer extends StatelessWidget {
  final String imagePath;
  final bool isNetwork;

  const ImageGalleryViewer({
    super.key,
    required this.imagePath,
    this.isNetwork = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: Hero(
          tag: imagePath,
          child: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4,
            child: isNetwork
                ? CachedNetworkImage(
                    imageUrl: imagePath,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white),
                    errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
                  )
                : Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                  ),
          ),
        ),
      ),
    );
  }
}
