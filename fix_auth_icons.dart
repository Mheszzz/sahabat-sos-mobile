import 'dart:io';

void main() {
  processLogin('lib/features/auth/presentation/login_page.dart');
  processReg1('lib/features/auth/presentation/register_step1_page.dart');
  processReg2('lib/features/auth/presentation/register_step2_page.dart');
}

void processLogin(String path) {
  var file = File(path);
  if (!file.existsSync()) return;
  var code = file.readAsStringSync();
  
  if (!code.contains("import 'package:flutter/cupertino.dart';")) {
    code = code.replaceFirst("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:flutter/cupertino.dart';");
  }
  
  code = code.replaceAll('Icons.volume_up_rounded', 'CupertinoIcons.volume_up');
  code = code.replaceAll('Icons.error_outline', 'CupertinoIcons.exclamationmark_circle');
  
  file.writeAsStringSync(code);
}

void processReg1(String path) {
  var file = File(path);
  if (!file.existsSync()) return;
  var code = file.readAsStringSync();
  
  if (!code.contains("import 'package:flutter/cupertino.dart';")) {
    code = code.replaceFirst("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:flutter/cupertino.dart';");
  }
  
  code = code.replaceAll('Icons.verified_rounded', 'CupertinoIcons.checkmark_seal');
  code = code.replaceAll('Icons.person_add_alt_1_outlined', 'CupertinoIcons.person_add');
  code = code.replaceAll('Icons.error_outline', 'CupertinoIcons.exclamationmark_circle');
  
  file.writeAsStringSync(code);
}

void processReg2(String path) {
  var file = File(path);
  if (!file.existsSync()) return;
  var code = file.readAsStringSync();
  
  if (!code.contains("import 'package:flutter/cupertino.dart';")) {
    code = code.replaceFirst("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:flutter/cupertino.dart';");
  }
  
  code = code.replaceAll('Icons.badge_outlined', 'CupertinoIcons.person_crop_circle_badge_checkmark');
  code = code.replaceAll('Icons.person_outline', 'CupertinoIcons.person');
  code = code.replaceAll('Icons.accessibility_new_rounded', 'CupertinoIcons.person_2'); // fallback for accessibility
  code = code.replaceAll('Icons.verified_rounded', 'CupertinoIcons.checkmark_seal');
  code = code.replaceAll('Icons.verified_user_outlined', 'CupertinoIcons.checkmark_shield');
  code = code.replaceAll('Icons.phone_outlined', 'CupertinoIcons.phone');
  code = code.replaceAll('Icons.work_outline', 'CupertinoIcons.briefcase');
  code = code.replaceAll('Icons.volunteer_activism_outlined', 'CupertinoIcons.heart');
  code = code.replaceAll('Icons.visibility_off_outlined', 'CupertinoIcons.eye_slash');
  code = code.replaceAll('Icons.hearing_disabled_outlined', 'CupertinoIcons.ear');
  code = code.replaceAll('Icons.speaker_notes_off_outlined', 'CupertinoIcons.speaker_slash');
  code = code.replaceAll('Icons.person_outline_rounded', 'CupertinoIcons.person');
  code = code.replaceAll('Icons.check', 'CupertinoIcons.checkmark_alt');
  code = code.replaceAll('Icons.tune_rounded', 'CupertinoIcons.slider_horizontal_3');
  code = code.replaceAll('Icons.record_voice_over_outlined', 'CupertinoIcons.mic');
  code = code.replaceAll('Icons.vibration_rounded', 'CupertinoIcons.waveform_path');
  code = code.replaceAll('Icons.hearing_rounded', 'CupertinoIcons.ear');
  code = code.replaceAll('Icons.text_increase_rounded', 'CupertinoIcons.textformat_size');
  
  file.writeAsStringSync(code);
}
