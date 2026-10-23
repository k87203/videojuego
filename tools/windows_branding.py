"""Brand a local copy of the official release template using native Windows resources.
The engine's embedded game pack is appended afterwards by Godot's exporter.
"""
import ctypes
from ctypes import wintypes
import io
import shutil
import struct
from pathlib import Path
from PIL import Image, ImageDraw

def block(key, value=b'', children=(), text=False):
    body = struct.pack('<HHH', 0, len(value)//2 if text else len(value), 1 if text else 0)
    body += (key+'\0').encode('utf-16le')
    body += b'\0' * (-len(body) % 4)
    body += value
    for child in children:
        body += b'\0' * (-len(body) % 4)
        body += child
    return struct.pack('<H', len(body)) + body[2:]

def version_resource():
    strings = {'CompanyName':'Proyecto independiente', 'FileDescription':'TECNO AVENTURA III: La mision del titulo', 'FileVersion':'0.4.1.0', 'InternalName':'TECNO_AVENTURA_III', 'OriginalFilename':'TECNO_AVENTURA_III.exe', 'ProductName':'TECNO AVENTURA III', 'ProductVersion':'0.4.1.0'}
    table = block('040904B0', children=[block(key, (value+'\0').encode('utf-16le'), text=True) for key,value in strings.items()], text=True)
    string_info = block('StringFileInfo', children=[table], text=True)
    var_info = block('VarFileInfo', children=[block('Translation', struct.pack('<HH', 0x409, 1200))], text=True)
    fixed = struct.pack('<13I', 0xFEEF04BD, 0x10000, 4, 0x10000, 4, 0x10000, 0x3F, 0, 0x40004, 1, 0, 0, 0)
    return block('VS_VERSION_INFO', fixed, [string_info, var_info])

def make_icon(path):
    # Same original graduation-cap emblem as assets/art/icon.svg, rendered at 8x.
    image = Image.new('RGBA', (1024,1024))
    draw = ImageDraw.Draw(image)
    scale = lambda points: [(int(x*8),int(y*8)) for x,y in points]
    draw.rounded_rectangle((0,0,1023,1023), radius=224, fill='#15314c')
    draw.polygon(scale([(14,50),(64,23),(114,50),(64,77)]), fill='#f4cc7e')
    draw.polygon(scale([(35,67),(35,88),(44,96),(64,102),(84,96),(93,88),(93,67),(64,83)]), fill='#6edbc8')
    draw.line(scale([(108,52),(108,90)]), fill='#f4cc7e', width=40)
    draw.ellipse((838,694,890,746), fill='#f4cc7e')
    image = image.resize((256,256), Image.Resampling.LANCZOS)
    image.save(path, format='ICO', sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])

def prepare_template(root):
    folder = root/'.godot'/'windows-template'
    original = folder/'windows_release_x86_64.exe'
    branded = folder/'tecno_release_x86_64.exe'
    icon_path = folder/'tecno.ico'
    make_icon(icon_path)
    shutil.copyfile(original, branded)
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.LoadLibraryExW.argtypes = [wintypes.LPCWSTR, wintypes.HANDLE, wintypes.DWORD]
    kernel.LoadLibraryExW.restype = wintypes.HMODULE
    kernel.FreeLibrary.argtypes = [wintypes.HMODULE]
    names=[]
    enum_type=ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HMODULE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_ssize_t)
    @enum_type
    def on_name(module, resource_type, name, param):
        names.append(name if name < 65536 else ctypes.wstring_at(name))
        return True
    kernel.EnumResourceNamesW.argtypes=[wintypes.HMODULE, ctypes.c_void_p, enum_type, ctypes.c_ssize_t]
    module=kernel.LoadLibraryExW(str(branded), None, 2|0x20)
    if not module: raise ctypes.WinError(ctypes.get_last_error())
    kernel.EnumResourceNamesW(module, ctypes.c_void_p(14), on_name, 0)
    kernel.FreeLibrary(module)
    kernel.BeginUpdateResourceW.argtypes=[wintypes.LPCWSTR,wintypes.BOOL]
    kernel.BeginUpdateResourceW.restype=wintypes.HANDLE
    kernel.UpdateResourceW.argtypes=[wintypes.HANDLE,ctypes.c_void_p,ctypes.c_void_p,wintypes.WORD,ctypes.c_void_p,wintypes.DWORD]
    kernel.EndUpdateResourceW.argtypes=[wintypes.HANDLE,wintypes.BOOL]
    handle=kernel.BeginUpdateResourceW(str(branded), False)
    if not handle: raise ctypes.WinError(ctypes.get_last_error())
    def update(kind, name, content):
        name_pointer=ctypes.c_void_p(name) if isinstance(name,int) else ctypes.cast(ctypes.c_wchar_p(name),ctypes.c_void_p)
        buf=ctypes.create_string_buffer(content)
        if not kernel.UpdateResourceW(handle,ctypes.c_void_p(kind),name_pointer,0x409,buf,len(content)):
            raise ctypes.WinError(ctypes.get_last_error())
    try:
        content=icon_path.read_bytes()
        count=struct.unpack_from('<H',content,4)[0]
        group=struct.pack('<HHH',0,1,count)
        for i in range(count):
            w,h,colors,reserved,planes,bits,size,offset=struct.unpack_from('<BBBBHHII',content,6+i*16)
            update(3,5000+i,content[offset:offset+size])
            group+=struct.pack('<BBBBHHIH',w,h,colors,0,planes,bits,size,5000+i)
        for name in names or [1]: update(14,name,group)
        update(16,1,version_resource())
        if not kernel.EndUpdateResourceW(handle,False): raise ctypes.WinError(ctypes.get_last_error())
    except Exception:
        kernel.EndUpdateResourceW(handle,True)
        raise
    return branded
