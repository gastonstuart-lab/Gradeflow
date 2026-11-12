import 'package:flutter/material.dart';
import 'package:gradeflow/design_lab/gradeflow_design_lab_app.dart';

// Independent design review entrypoint. Does not load Firebase, AuthService,
// the repository factory, student data or any production route.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GradeFlowDesignLabApp());
}
