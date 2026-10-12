import json,re,ast,secrets,hashlib
from pathlib import Path
root=Path(__file__).resolve().parent
src=root/'source-snapshot'
def write(path,value): path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
def split(s):
    parts=[];start=0;depth=0;quoted=False;escaped=False
    for i,c in enumerate(s):
        if quoted:
            if escaped: escaped=False
            elif c=='\\': escaped=True
            elif c=='"': quoted=False
        elif c=='"': quoted=True
        elif c in '[(': depth+=1
        elif c in '])': depth-=1
        elif c==',' and depth==0: parts.append(s[start:i].strip());start=i+1
    parts.append(s[start:].strip());return parts

def value(s):
    s=s.strip()
    if s=='true':return True
    if s=='false':return False
    if s=='nil':return None
    if s.startswith('"'):return json.loads(s)
    if s.startswith('['):
        inner=s[1:-1];items=split(inner)
        if not inner:return []
        if ':' in items[0] and not items[0].startswith('"'): return {str(value(k)):value(v) for k,v in (i.split(':',1) for i in items)}
        return [value(i) for i in items]
    return int(s)
def inits(text,label):
    section=text.split('static let '+label+':',1)[1].split('\n    ]',1)[0]
    return [dict((k.strip(),value(v)) for k,v in (p.split(':',1) for p in split(m))) for m in re.findall(r'\.init\((.*?)\),?\n',section+'\n')]
text=(src/'CommunityContentCatalog.swift').read_text()
members=inits(text,'members');rooms=inits(text,'rooms');gifts=inits(text,'keepsakes')
for r in rooms:
    r['targetAudience']=r.pop('audienceGoal');r.update(mutedSeatNumbers=[],roomConversation=[],hostNote='Make space for every voice.',moderatorMemberIDs=[])
for g in gifts:g['tokenCost']=g.pop('coinPrice')
media=json.loads((src/'community-media.json').read_text())
starters=inits((src/'ConversationStarters.swift').read_text(),'collection')
packs=inits((src/'KokoCoinCatalog.swift').read_text(),'packs')
seed=(src/'KokoMomentConversationSeeds.swift').read_text()
openings=dict(re.findall(r'"([^"\n]+)": ("(?:[^"\\]|\\.)*")',seed.split('private static let replies')[0]));openings={k:json.loads(v) for k,v in openings.items()}
replies=[json.loads(m) for m in re.findall(r'"(?:[^"\\]|\\.)*"',seed.split('private static let replies = [')[1].split(']')[0])]
engagement=[]
for index,m in enumerate(media):
    authors=[x['id'] for x in members if x['id']!=m['curatorMemberID']];mid=m['momentKey'];comments=[]
    if mid in openings:
        for pos in range(2+index%3): comments.append(dict(id=f'moment-seed-{mid}-{pos}',authorMemberID=authors[(index+pos)%len(authors)],messageText=openings[mid] if pos==0 else replies[(index*3+pos)%len(replies)],postedAt=-978307200))
    engagement.append(dict(id=mid,likeCount=9+(index*29+index//3*11)%173,comments=comments))
video_map=dict(re.findall(r'"([^"\n]+)": "(clip-[^"\n]+)"',(src/'CommunityMediaCatalog.swift').read_text()))
room_script=(src/'KokoRoomDemoSession.swift').read_text()
phrases={}
for label,body in re.findall(r'(case "[^"]+"|default): return \[(.*?)\]',room_script):
    phrases[json.loads(label[5:]) if label.startswith('case ') else 'Conversation']=json.loads('['+body+']')
collections={'members' :members,'rooms':rooms,'keepsakes':gifts,'media':media,'starters':starters,'engagement':engagement,'arrangement':dict(topics=['All','Conversation','Music','Creative','After hours'],roomVideoKeys=video_map,coinPacks=packs,roomPhrases=phrases)}
for key,records in collections.items():write(root/'responses'/f'{key}.json',dict(code=0,message='ok',data=records))
contract_file=root/'contract.json'
if not contract_file.exists():
    c=dict(schemaVersion=1,namespace='koko',baseURL='https://koko.dfbbdr.top',sourceAppId='80895233',endpoints=dict(loginMethods='/koko/arrival/entryways',authenticate='/koko/arrival/'+secrets.choice(['room-pass','open-invitation','listening-pass']),confirmPurchase='/koko/keepsakes/settlement'),endpointResponses=dict(loginMethods='responses/login-methods.json',authenticate='responses/auth-response.json',confirmPurchase='responses/purchase-response.json'),requestFields=dict(appVersion='koko_edition',pushToken='arrival_chime',deviceNo='listener_installation',transactionId='apple_keepsake_transaction',payload='keepsake_receipt',callbackResult='room_order_reference',roomPushMsgType='room_delivery_kind'),h5Fields=dict(orderCode='roomOrder',batchNo='keepsakeProduct',openUrl='outsideDestination'),additionalLoginFields=dict(loginType='arrival_method',scene='arrival_purpose',email='member_mailbox',password='member_passphrase',appleToken='apple_identity_assertion',appleAuthorizationCode='apple_authorization_exchange',appleUserId='apple_member_subject'),responseFields=dict(code='code',message='message',data='data',token='token'),loginFlags=dict(apple='apple_arrival',email='mailbox_arrival',visitor='visitor_arrival',register='new_member_arrival'),ably=dict(clientId='app',serverClientIds=['serve'],allowMissingServerClientId=True,rewind=1),eventTransport=dict(jsonEnvelopeEventKinds=['logout']),events={},contentRoutes=[dict(key=k,path='/koko/community/'+k,file=f'responses/{k}.json') for k in collections])
    for role,name,payload in [('linkSuccessMessage','KokoRoomInvitation',{'room':{'destination':'#{h5Url}'}}),('pay','KokoKeepsakeOrder',{'keepsake':{'order':'#{orderCode}','product':'#{batchNo}'}}),('logout','KokoDeparture',{}),('openBrowser','KokoOutsideVisit',{'visit':{'destination':'#{openUrl}'}})]:c['events'][role]=dict(name=name,discriminator=['occasion'],template=dict(occasion=name,**payload))
    write(contract_file,c)
write(root/'responses/login-methods.json',dict(code=0,message='ok',data=dict(apple_arrival=1,mailbox_arrival=1,visitor_arrival=0,new_member_arrival=1)))
write(root/'responses/auth-response.json',dict(code=0,message='ok',data=dict(token='#{tokenResult}')))
write(root/'responses/purchase-response.json',dict(code=503,message='Purchase verification must be handled by the settlement service',data=None))
write(root/'source-inventory.json',dict(collections={k:dict(count=len(v) if isinstance(v,list) else len(v),ids=[x['id'] for x in v] if isinstance(v,list) and v and 'id' in v[0] else []) for k,v in collections.items()},sourceHashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in src.iterdir()},mediaOrigins={m['id']:'bundle:'+m['sourceFolder']+'/'+m['sourceFilename'] for m in media}))
print({k:len(v) for k,v in collections.items()})
