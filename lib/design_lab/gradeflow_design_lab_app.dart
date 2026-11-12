import 'package:flutter/material.dart';
import 'package:gradeflow/components/home/gradeflow_weather_visuals.dart';
import 'package:gradeflow/components/home/teacher_home_class_rail.dart';
import 'package:gradeflow/components/home/teacher_home_clock.dart';
import 'package:gradeflow/components/home/teacher_home_presentation.dart';
import 'package:gradeflow/config/instructos_design.dart';
import 'package:gradeflow/design_lab/gradebook_lab_sample.dart';
import 'package:gradeflow/models/class.dart';
import 'package:gradeflow/services/gradeflow_weather_service.dart';

/// Separate entrypoint for reviewing real GradeFlow widgets with synthetic
/// data. No Firebase initialization, sign-in, student records or writes.
class GradeFlowDesignLabApp extends StatefulWidget {
  const GradeFlowDesignLabApp({super.key});

  @override
  State<GradeFlowDesignLabApp> createState() => _GradeFlowDesignLabAppState();
}

enum _LabPage { overview, weather, grading, home }
enum _LabDevice { desktop, tablet, surfaceCompact }

class _GradeFlowDesignLabAppState extends State<GradeFlowDesignLabApp> {
  ThemeMode _theme = ThemeMode.light;
  _LabPage _page = _LabPage.overview;
  _LabDevice _device = _LabDevice.desktop;
  String _classId = 'j2-science';

  static const _titles = <_LabPage, String>{
    _LabPage.overview: 'Component overview',
    _LabPage.weather: 'Weather forecast',
    _LabPage.grading: 'Gradebook quick entry',
    _LabPage.home: 'Home components',
  };

  static const _icons = <_LabPage, IconData>{
    _LabPage.overview: Icons.space_dashboard_outlined,
    _LabPage.weather: Icons.cloud_outlined,
    _LabPage.grading: Icons.grid_on_outlined,
    _LabPage.home: Icons.home_outlined,
  };

  static const _forecast = GradeFlowWeather(
    temperature: 26,
    feelsLike: 27,
    humidity: 47,
    windKmh: 4,
    weatherCode: 0,
    isDay: true,
    observedTime: '2026-11-12T10:00',
    hours: [
      GradeFlowWeatherHour(localTime:'2026-11-12T10:00',temperature:26,rainChance:0,weatherCode:0),
      GradeFlowWeatherHour(localTime:'2026-11-12T11:00',temperature:27,rainChance:0,weatherCode:1),
      GradeFlowWeatherHour(localTime:'2026-11-12T12:00',temperature:28,rainChance:0,weatherCode:2),
      GradeFlowWeatherHour(localTime:'2026-11-12T13:00',temperature:28,rainChance:0,weatherCode:2),
      GradeFlowWeatherHour(localTime:'2026-11-12T14:00',temperature:29,rainChance:0,weatherCode:2),
      GradeFlowWeatherHour(localTime:'2026-11-12T15:00',temperature:28,rainChance:10,weatherCode:2),
      GradeFlowWeatherHour(localTime:'2026-11-12T16:00',temperature:27,rainChance:20,weatherCode:2),
      GradeFlowWeatherHour(localTime:'2026-11-12T17:00',temperature:26,rainChance:40,weatherCode:61),
      GradeFlowWeatherHour(localTime:'2026-11-12T18:00',temperature:25,rainChance:35,weatherCode:61),
      GradeFlowWeatherHour(localTime:'2026-11-12T19:00',temperature:24,rainChance:20,weatherCode:2),
      GradeFlowWeatherHour(localTime:'2026-11-12T20:00',temperature:23,rainChance:15,weatherCode:1),
      GradeFlowWeatherHour(localTime:'2026-11-12T21:00',temperature:22,rainChance:5,weatherCode:0),
    ],
    days: [
      GradeFlowWeatherDay(localDate:'2026-11-12',low:18,high:29,rainChance:0,weatherCode:0),
      GradeFlowWeatherDay(localDate:'2026-11-13',low:20,high:28,rainChance:10,weatherCode:2),
      GradeFlowWeatherDay(localDate:'2026-11-14',low:19,high:26,rainChance:55,weatherCode:61),
      GradeFlowWeatherDay(localDate:'2026-11-15',low:18,high:25,rainChance:35,weatherCode:2),
      GradeFlowWeatherDay(localDate:'2026-11-16',low:17,high:27,rainChance:20,weatherCode:1),
    ],
  );

  List<Class> get _classes {
    final date = DateTime(2026, 9, 1);
    return [
      for (final item in const [
        ('j2-science','J2ABC G4','Science'),
        ('j1-english','J1FG G1','English / EEP'),
        ('j3-english','J3DE G5','English / EEP'),
        ('j1-pa','J1 Performance Arts','Performance Arts'),
      ])
        Class(
          classId:item.$1,className:item.$2,subject:item.$3,
          schoolYear:'2026',term:'Fall',teacherId:'design-lab',
          createdAt:date,updatedAt:date,
        ),
    ];
  }

  ThemeData _themeData(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: InstructOSDesign.teal, brightness: brightness),
      scaffoldBackgroundColor: dark
          ? InstructOSDesign.night : InstructOSDesign.canvas,
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner:false,
    title:'GradeFlow Design Lab',
    theme:_themeData(Brightness.light),
    darkTheme:_themeData(Brightness.dark),
    themeMode:_theme,
    home:Builder(builder:(context) => _scaffold(context)),
  );

  Widget _scaffold(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 850;
    return Scaffold(
      body:SafeArea(child:Column(children:[
        Container(
          padding: const EdgeInsets.symmetric(horizontal:20,vertical:12),
          decoration:BoxDecoration(color:scheme.surface,
            border:Border(bottom:BorderSide(color:scheme.outlineVariant))),
          child:Row(children:[
            const InstructOSBrandMark(size:38),
            const SizedBox(width:11),
            const Expanded(child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Text('GradeFlow Design Lab',style:TextStyle(
                  fontWeight:FontWeight.w900,fontSize:18)),
                Text('Isolated component gallery · sample data only',
                    style:TextStyle(fontSize:11)),
              ],
            )),
            IconButton(
              key:const ValueKey('lab-toggle-theme'),
              tooltip:'Switch light/dark theme',
              onPressed:()=>setState(()=>_theme = _theme == ThemeMode.dark
                  ? ThemeMode.light : ThemeMode.dark),
              icon:Icon(_theme == ThemeMode.dark
                  ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            ),
          ]),
        ),
        Expanded(child:Row(children:[
          if(wide) _sideNavigation(context),
          Expanded(child:Column(children:[
            if(!wide) _mobileNavigation(),
            _deviceToolbar(context),
            Expanded(child:SingleChildScrollView(
              key:const ValueKey('lab-main-scroll'),
              padding:const EdgeInsets.fromLTRB(20,20,20,45),
              child:Center(child:ConstrainedBox(
                constraints:BoxConstraints(maxWidth:switch(_device) {
                  _LabDevice.desktop => 1280,
                  _LabDevice.tablet => 820,
                  _LabDevice.surfaceCompact => 410,
                }),
                child:_pageContent(context),
              )),
            )),
          ])),
        ])),
      ])),
    );
  }

  Widget _sideNavigation(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width:210,
      decoration:BoxDecoration(color:scheme.surface,
        border:Border(right:BorderSide(color:scheme.outlineVariant))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Padding(padding:EdgeInsets.fromLTRB(18,24,16,8),
          child:Text('COMPONENTS',style:TextStyle(
            fontSize:10.5,fontWeight:FontWeight.w900,letterSpacing:1))),
        for(final item in _LabPage.values)
          Padding(
            padding:const EdgeInsets.symmetric(horizontal:9,vertical:2),
            child:ListTile(
              key:ValueKey('lab-nav-${item.name}'),
              dense:true,
              shape:RoundedRectangleBorder(
                  borderRadius:BorderRadius.circular(12)),
              selected:item==_page,
              selectedTileColor:scheme.primaryContainer,
              leading:Icon(_icons[item],size:20),
              title:Text(_titles[item]!,style:const TextStyle(fontSize:13)),
              onTap:()=>setState(()=>_page=item),
            ),
          ),
        const Spacer(),
        const Padding(padding:EdgeInsets.all(15),child:Text(
          'Private prototype. Never connected to school data.',
          style:TextStyle(fontSize:11))),
      ]),
    );
  }

  Widget _mobileNavigation() => SingleChildScrollView(
    scrollDirection:Axis.horizontal,
    padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),
    child:Row(children:[
      for(final item in _LabPage.values)
        Padding(padding:const EdgeInsets.only(right:7),child:ChoiceChip(
          key:ValueKey('lab-nav-${item.name}'),
          label:Text(_titles[item]!),
          selected:_page==item,
          onSelected:(_)=>setState(()=>_page=item),
        )),
    ]),
  );

  Widget _deviceToolbar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding:const EdgeInsets.symmetric(horizontal:18,vertical:9),
      decoration:BoxDecoration(color:scheme.surface,
        border:Border(bottom:BorderSide(color:scheme.outlineVariant))),
      child:Row(children:[
        Expanded(child:Text(_titles[_page]!,
          maxLines:1,overflow:TextOverflow.ellipsis,
          style:const TextStyle(fontWeight:FontWeight.w800))),
        PopupMenuButton<_LabDevice>(
          key:const ValueKey('lab-device-selector'),
          tooltip:'Preview width',
          icon:const Icon(Icons.devices_outlined),
          onSelected:(next)=>setState(()=>_device=next),
          itemBuilder:(_)=>const [
            PopupMenuItem(value:_LabDevice.desktop,child:Text('Desktop · full width')),
            PopupMenuItem(value:_LabDevice.tablet,child:Text('Tablet / Surface · 820 px')),
            PopupMenuItem(value:_LabDevice.surfaceCompact,child:Text('Compact · 410 px')),
          ],
        ),
      ]),
    );
  }

  Widget _pageContent(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Expanded(child:Text(_titles[_page]!,
          style:Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight:FontWeight.w900,letterSpacing:-.7))),
        Container(
          padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
          decoration:BoxDecoration(borderRadius:BorderRadius.circular(50),
            color:scheme.secondaryContainer),
          child:const Text('DEMO ONLY',style:TextStyle(fontSize:10,
            letterSpacing:1,fontWeight:FontWeight.w900)),
        ),
      ]),
      const SizedBox(height:8),
      Text('Review approved components and try candidate controls before '
           'anything reaches the live GradeFlow.',
        style:TextStyle(color:scheme.onSurfaceVariant,fontSize:13)),
      const SizedBox(height:22),
      switch(_page) {
        _LabPage.overview => _overview(context),
        _LabPage.weather => _weather(context),
        _LabPage.grading => _grading(context),
        _LabPage.home => _home(context),
      },
    ]);
  }

  Widget _overview(BuildContext context) {
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      _labSection(context,'Approved weather','Actual production weather visuals',
        GradeFlowWeatherHero(forecast:_forecast)),
      const SizedBox(height:18),
      _labSection(context,'Gradebook concept','Interactive fast-entry demo',
        const GradeFlowGradebookLabSample()),
      const SizedBox(height:18),
      _labSection(context,'Home foundation','Approved card and clock controls',
        Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const TeacherHomeClock(color:InstructOSDesign.ink),
          const SizedBox(height:16),
          Text('The card material and spacing here use the actual Home widget.',
            style:Theme.of(context).textTheme.bodyMedium),
        ])),
    ]);
  }

  Widget _weather(BuildContext context) {
    return Column(children:[
      _labSection(context,'Current conditions','Approved weather hero',
        GradeFlowWeatherHero(forecast:_forecast)),
      const SizedBox(height:18),
      _labSection(context,'Hourly trend','Drag or scroll to later hours',
        GradeFlowHourlyWeather(hours:_forecast.hours)),
      const SizedBox(height:18),
      _labSection(context,'Five-day overview','Shared high/low scale',
        GradeFlowDailyWeather(days:_forecast.days)),
    ]);
  }

  Widget _grading(BuildContext context) => _labSection(
    context,'Compact grading table',
    'Prototype: +/- score changes, tap a score for numeric entry',
    const GradeFlowGradebookLabSample());

  Widget _home(BuildContext context) => Column(children:[
    _labSection(context,'Approved class carousel','Select a demo class',
      TeacherHomeClassRail(
        classes:_classes,selectedClassId:_classId,
        studentCounts:const {
          'j2-science':18,'j1-english':20,
          'j3-english':15,'j1-pa':19,
        },
        onSelectClass:(id)=>setState(()=>_classId=id),
      )),
    const SizedBox(height:18),
    TeacherHomeCard(title:'Your week',child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,
      children:[
        Text('Needs attention',style:Theme.of(context)
          .textTheme.titleSmall),
        const SizedBox(height:8),
        const Text('Prepare J2 Science notes · Friday'),
        const Divider(height:24),
        Text('Coming up',style:Theme.of(context).textTheme.titleSmall),
        const SizedBox(height:8),
        const Text('School assembly · Monday'),
        const Text('J1 English assessment · Wednesday'),
      ],
    )),
  ]);

  Widget _labSection(
    BuildContext context,String title,String description,Widget content,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[
        Expanded(child:Text(title,style:Theme.of(context)
          .textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800))),
        Icon(Icons.verified_outlined,color:scheme.primary,size:19),
      ]),
      const SizedBox(height:3),
      Text(description,style:TextStyle(fontSize:11.5,
        color:scheme.onSurfaceVariant)),
      const SizedBox(height:10),
      TeacherHomeCard(title:title,child:content),
    ]);
  }
}
