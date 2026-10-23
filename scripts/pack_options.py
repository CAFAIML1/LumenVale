"""Check exported settings/profile values using the documented Iris grammar.

This checks the emitted pack, without pretending to execute Iris itself.
"""
from pathlib import Path
import re

def load_profiles(shader_root):
    shader_root=Path(shader_root)
    settings=(shader_root/'lib'/'settings.glsl').read_text(encoding='utf-8')
    defaults={}; values={}
    for line in settings.splitlines():
        m=re.match(r'\s*(//\s*)?#define\s+(\w+)\s*(.*?)\s*(?://.*)?$',line)
        if m:
            disabled,name,value=m.groups()
            # Parse values before the description, not as part of the macro.
            value=value.split('//',1)[0].strip()
            if not value: defaults[name]=disabled is None
            elif not disabled: defaults[name]=value
            choices=re.search(r'//\s*\[([^]]+)\]',line)
            if choices: values[name]=choices[1].split()
        c=re.match(r'const (?:int|float) (\w+) = ([^;]+);\s*//\s*\[([^]]+)\]',line)
        if c: defaults[c[1]]=c[2].strip(); values[c[1]]=c[3].split()
    all_source='\n'.join(p.read_text(encoding='utf-8') for p in (shader_root/'lib').glob('*') if p.suffix in ('.glsl','.fsh','.vsh'))
    bool_refs=set(re.findall(r'^\s*#ifn?def\s+(\w+)',all_source,re.M))
    profiles={}
    props=(shader_root/'shaders.properties').read_text(encoding='utf-8')
    for line in props.splitlines():
        if not line.startswith('profile.'):continue
        name,text=line.split('=',1); parsed={}
        for token in text.split():
            if ':' in token or '=' in token:
                key,value=re.split(r'[:=]',token,maxsplit=1)
                assert key in values,f'Unknown numerical setting: {key}'
                assert value in values[key],f'{key}: value {value} absent from menu'
            else:
                key=token.lstrip('!');value=not token.startswith('!')
                assert isinstance(defaults.get(key),bool) and key in bool_refs,f'Unrecognized Iris boolean: {key}'
            assert key not in parsed,f'Duplicate profile option: {key}'
            parsed[key]=value
        profiles[name.removeprefix('profile.')]=parsed
    assert len(profiles)==4
    assert all(set(p)==set(profiles['BALANCED']) for p in profiles.values()),'Profiles must reset the same option set'
    assert all(defaults[k]==v for k,v in profiles['BALANCED'].items()),'Default settings must match Balanced'
    return profiles
