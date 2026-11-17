"""Fetch only the Windows plugin and editor resources from the official zip.
HTTP byte ranges avoid downloading Linux/macOS binaries that this build cannot use.
"""
import io, urllib.request, zipfile, time
from pathlib import Path

URL='https://github.com/TokisanGames/Terrain3D/releases/download/v1.1.0-stable/Terrain3D_v1.1.0-stable.zip'
ROOT=Path(__file__).resolve().parents[2]

class RemoteZip(io.RawIOBase):
    def __init__(self):
        self.url=URL;self.pos=0;self.size=45665295;self.cache={}
    def seekable(self):return True
    def readable(self):return True
    def tell(self):return self.pos
    def seek(self,offset,whence=0):
        self.pos=(self.size if whence==2 else self.pos if whence==1 else 0)+offset
        return self.pos
    def read(self,size=-1):
        if size<0:size=self.size-self.pos
        if size==0:return b''
        start=self.pos;end=min(self.size,start+size)-1
        for retry in range(4):
            try:
                req=urllib.request.Request(self.url,headers={'Range':f'bytes={start}-{end}','User-Agent':'ProjectZ-Terrain-Prototyping'})
                with urllib.request.urlopen(req,timeout=45) as response:
                    self.url=response.url
                    if response.status!=206:raise RuntimeError(f'Range unsupported: {response.status}')
                    raw=response.read()
                if len(raw)!=end-start+1:raise RuntimeError('Short range response')
                self.pos=end+1;return raw
            except Exception as error:
                print(f'Range {start}:{end} retry {retry}: {error}',flush=True)
                if retry==3:raise
                time.sleep(1)

def main():
    remote=RemoteZip()
    with zipfile.ZipFile(remote) as archive:
        names=archive.namelist()
        selected=[]
        for name in names:
            if '/addons/terrain_3d/' in '/'+name or name.lower().endswith(('license','license.txt','license.md')):
                if name.endswith('/'):continue
                if '/bin/' in name and not ('windows' in name.lower() and 'x86_64' in name.lower()):continue
                selected.append(name)
        print(f'Extracting {len(selected)} plugin files',flush=True)
        for i,name in enumerate(selected):
            if 'addons/terrain_3d/' in name:
                relative=name[name.index('addons/terrain_3d/'):]
            else:relative='addons/terrain_3d/'+Path(name).name
            dest=ROOT.parent/relative
            if dest.exists() and dest.stat().st_size==archive.getinfo(name).file_size:continue
            data=archive.read(name);dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
            print(f'{i+1}/{len(selected)} {relative} {len(data)}',flush=True)

if __name__=='__main__':main()
