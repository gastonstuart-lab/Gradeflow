import 'gradebook_workspace.dart';

/// Pure validation: no writes occur while inspecting a standalone backup.
class GradebookImportPlan {
  GradebookImportPlan(this.columns,this.scores,this.exams);
  final Map<String,List<String>> columns;
  final Map<String,Map<String,List<double?>>> scores;
  final Map<String,double?> exams;
  int get entered => scores.values.fold(0,(n,c)=>n+c.values.fold(0,(n,v)=>n+v.whereType<double>().length))+exams.values.whereType<double>().length;
  static GradebookImportPlan parse(Map<String,dynamic> source,Set<String> roster){
    final rawColumns=source['columns'],rawScores=source['scores'];
    if(rawColumns is! Map || rawScores is! Map || rawScores.isEmpty || rawScores.keys.any((id)=>id is! String||!roster.contains(id))) throw const FormatException('Backup student IDs do not match this class. Nothing has been imported.');
    double? number(Object? v){if(v==null)return null;if(v is! num||!v.isFinite||v<0||v>100)throw const FormatException('Backup scores must be numbers from 0 to 100.');return v.toDouble();}
    final columns=<String,List<String>>{};
    for(final k in GradebookWorkspace.processWeights.keys){final list=rawColumns[k];if(list is! List||list.isEmpty||list.length>40||list.any((v)=>v is! String||v.trim().isEmpty||v.length>60)||list.toSet().length!=list.length)throw FormatException('Invalid assessment names for $k.');columns[k]=list.cast<String>();}
    final scores=<String,Map<String,List<double?>>>{},exams=<String,double?>{};
    for(final entry in rawScores.entries){final id=entry.key as String,r=entry.value;if(r is! Map)throw const FormatException('Invalid student record.');exams[id]=number(r['exam']);scores[id]={};for(final k in columns.keys){final cells=r[k];if(cells is! List||cells.length!=columns[k]!.length)throw const FormatException('Assessment columns do not match scores.');scores[id]![k]=cells.map(number).toList();}}
    return GradebookImportPlan(columns,scores,exams);
  }
}
