import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/communication_access.dart';
import 'package:gradeflow/models/communication_models.dart';

void main() {
  Map<String, dynamic> valid() => {
        'active': true,
        'schoolKey': 'school-a',
        'role': 'teacher',
        'displayName': 'Fictional Teacher',
        'channelIds': ['staff']
      };
  test('administrator-provisioned UID access grants only listed channels', () {
    final access = CommunicationAccess.fromData(valid());
    expect(access.role, CommunicationRole.teacher);
    access.requireChannel('staff');
    expect(() => access.requireChannel('private'), throwsStateError);
    expect(() => access.channelIds.add('private'), throwsUnsupportedError);
  });
  test('missing, revoked or malformed access fails closed', () {
    expect(() => CommunicationAccess.fromData(null), throwsStateError);
    for (final change in <Map<String, dynamic>>[
      {'active': false},
      {'active': 'true'},
      {'role': 'owner'},
      {'role': 5},
      {'schoolKey': 'school-a/other'},
      {'displayName': ''},
      {'displayName': 'x' * 101},
      {
        'channelIds': ['staff', 45]
      },
      {
        'channelIds': ['staff/other']
      },
      {'channelIds': List.filled(101, 'staff')},
    ]) {
      expect(() => CommunicationAccess.fromData({...valid(), ...change}),
          throwsStateError);
    }
  });
}
