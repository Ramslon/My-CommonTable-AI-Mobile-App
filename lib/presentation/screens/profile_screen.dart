import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:commontable_ai_app/core/services/storage_service.dart';
import 'package:commontable_ai_app/core/services/firebase_boot.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameCtrl.text = user?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final name = _nameCtrl.text.trim();
      if (name.isNotEmpty) {
        await user.updateDisplayName(name);
      }
      // Persist to Firestore profile as well
      if (FirebaseBoot.available) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'displayName': name,
          'photoURL': user.photoURL,
          'updatedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePhoto() async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1080);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      await _uploadAndSetPhoto(bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image pick failed')));
    }
  }

  Future<void> _uploadAndSetPhoto(Uint8List bytes) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!FirebaseBoot.available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cloud storage unavailable in offline mode')));
      return;
    }
    setState(() => _saving = true);
    try {
      final url = await StorageService().uploadImageBytes(bytes, folder: 'profile');
      await user.updatePhotoURL(url);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'photoURL': url,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {}); // refresh UI
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photo = user?.photoURL;
    final email = user?.email ?? '(anonymous)';

    return Scaffold(
      appBar: AppBar(title: const Text('Account Information')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundImage: photo != null ? NetworkImage(photo) : null,
                  child: photo == null ? const Icon(Icons.person, size: 48) : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _saving ? null : _changePhoto,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.green,
                      child: const Icon(Icons.edit, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text(email, style: const TextStyle(color: Colors.black54))),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save changes'),
            ),
          ),
        ],
      ),
    );
  }
}
