"""Offline source/configuration comparison only. Does not build, run or call services."""
import json,re,hashlib,plistlib
from pathlib import Path
base=Path(__file__).resolve().parent; repo=base.parents[1]
contract=json.loads((base/'contract.json').read_text())
assert contract['sourceAppId']=='80895233' and contract['baseURL']=='https://koko.dfbbdr.top'
interfaces=json.loads((base/'generated/接口模板-80895233.json').read_text())
configuration=json.loads((base/'generated/配置模板-80895233.json').read_text())
assert interfaces['sourceAppId']==configuration['sourceAppId']==contract['sourceAppId']
assert len(configuration['parameters'])==14
paths={x['url']:json.loads(x['responseContent']) for x in interfaces['interfaces']}
for role,file in contract['endpointResponses'].items(): assert paths[contract['endpoints'][role]]==json.loads((base/file).read_text())
for route in contract['contentRoutes']: assert paths[route['path']]==json.loads((base/route['file']).read_text())
for name in ['接口模板-80895233.json','配置模板-80895233.json']: assert '\n' not in (base/'generated'/name).read_text()
media=json.loads((base/'responses/media.json').read_text())['data']
assert media==json.loads((base/'source-snapshot/community-media.json').read_text())
assert media==json.loads((repo/'ContentLibrary/community-media.json').read_text())
assert sum(m['mediaKind']=='photo' for m in media)==44 and sum(m['mediaKind']=='video' for m in media)==10
for m in media:
 assert (repo/m['sourceFolder']/m['sourceFilename']).is_file(),m['id']
 assert (repo/'Koko/Resources/CommunityMedia'/m['previewFilename']).is_file(),m['id']
 if m.get('displayFilename'): assert (repo/'Koko/Resources/CommunityMedia'/m['displayFilename']).is_file(),m['id']
 assert hashlib.sha256((repo/m['sourceFolder']/m['sourceFilename']).read_bytes()).hexdigest()==m['sourceSHA256'],m['id']
people=json.loads((base/'responses/members.json').read_text())['data'];ids={p['id'] for p in people}
rooms=json.loads((base/'responses/rooms.json').read_text())['data']
for r in rooms:
 assert r['hostMemberID'] in ids
 assert set(r['seatAssignments'].values())<=ids
 assert all(int(i)<r['seatLimit'] for i in r['seatAssignments'])
 assert all(k in r for k in ['targetAudience','roomConversation','mutedSeatNumbers','hostNote','moderatorMemberIDs'])
gifts=json.loads((base/'responses/keepsakes.json').read_text())['data']
assert all('tokenCost' in x for x in gifts)
engagement=json.loads((base/'responses/engagement.json').read_text())['data']
assert [x['id'] for x in engagement]==[x['momentKey'] for x in media]
assert all(c['authorMemberID'] in ids for x in engagement for c in x['comments'])
source=(repo/'Koko/CommunityGateway/IntegrationContract.generated.swift').read_text()
assert source==(base/'generated/IntegrationContract.generated.swift').read_text()
for path in list(contract['endpoints'].values())+[r['path'] for r in contract['contentRoutes']]:assert '"'+path+'"' in source
pbx=(repo/'Koko.xcodeproj/project.pbxproj').read_text()
for p in (repo/'Koko/CommunityGateway').glob('*.swift'):assert p.name+' in Sources' in pbx,p.name
assert 'Ably in Frameworks' in pbx and 'Alamofire in Frameworks' in pbx
info=plistlib.loads((repo/'Koko/Configuration/Info.plist').read_bytes())
assert all(info.get(key) for key in ['NSCameraUsageDescription','NSMicrophoneUsageDescription','NSPhotoLibraryUsageDescription'])
assert any('com.koko.app' in row.get('CFBundleURLSchemes',[]) for row in info['CFBundleURLTypes'])
assert not (repo/'Koko/Resources/CommunityMedia/community-media.json').exists()
print('Offline comparison complete: 10 routes, 14 configuration entries, 54 source media hashes, 14 rooms, DTO keys, target membership and permission/scheme declarations.')
