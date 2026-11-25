unit uLang;

{$mode objfpc}{$H+}

interface

uses
  Windows, SysUtils;

type
  { 全部用户可见文案的键，按枚举顺序与 ZH_TEXT/EN_TEXT 一一对应 }
  TLangKey = (
    lkSettingsCaption, lkTrigger, lkTop, lkBottom, lkLeft, lkRight,
    lkDwellMs, lkZonePx, lkAutoRun, lkMenuItems, lkAdd, lkAddChild, lkAddSep,
    lkDelete, lkMoveUp, lkMoveDown, lkName, lkType, lkTarget, lkParams,
    lkWorkDir, lkBrowse, lkAdmin, lkSave, lkCancel, lkTypeApp, lkTypeUrl,
    lkTypeDir, lkTypeSep, lkNewItem, lkNewChild, lkUntitled, lkEmptyMenu,
    lkTraySettings, lkTrayExit, lkLanguage, lkProgFilter, lkDirNotExist,
    lkAppNotExist, lkLangSystem
  );

  TLangNotify = procedure of object;

{ 取当前语言的文案 }
function L(Key: TLangKey): string;
{ 无配置文件时按系统 UI 语言推断 'zh'/'en' }
function DetectDefaultLang: string;
{ 切换语言（'zh'/'en'/'system'），并通知已显示的界面刷新文案；
  'system' 表示跟随系统 UI 语言 }
procedure SetLanguage(const ACode: string);

var
  OnLanguageChanged: TLangNotify;  // 语言切换后的回调（托盘菜单等）

implementation

const
  ZH_TEXT: array[TLangKey] of string = (
    'octopus-launch 设置',               // lkSettingsCaption
    '触发',                               // lkTrigger
    '上边',                               // lkTop
    '下边',                               // lkBottom
    '左边',                               // lkLeft
    '右边',                               // lkRight
    '贴边停留(毫秒):',                    // lkDwellMs
    '触发区宽度(px):',                    // lkZonePx
    '开机自启',                           // lkAutoRun
    '菜单项',                             // lkMenuItems
    '新增项目',                           // lkAdd
    '新增子项',                           // lkAddChild
    '新增分隔符',                         // lkAddSep
    '删除',                               // lkDelete
    '上移',                               // lkMoveUp
    '下移',                               // lkMoveDown
    '名称:',                              // lkName
    '类型:',                              // lkType
    '目标:',                              // lkTarget
    '参数:',                              // lkParams
    '工作目录:',                          // lkWorkDir
    '浏览...',                            // lkBrowse
    '以管理员身份运行',                   // lkAdmin
    '保存',                               // lkSave
    '取消',                               // lkCancel
    '软件',                               // lkTypeApp
    '网址',                               // lkTypeUrl
    '目录',                               // lkTypeDir
    '分隔符',                             // lkTypeSep
    '新项目',                             // lkNewItem
    '新子项',                             // lkNewChild
    '(未命名)',                           // lkUntitled
    '菜单为空，请先在设置中添加菜单项。',  // lkEmptyMenu
    '设置...',                            // lkTraySettings
    '退出',                               // lkTrayExit
    '语言:',                              // lkLanguage
    '程序|*.exe;*.lnk;*.bat;*.cmd|所有文件|*.*',  // lkProgFilter
    '目录不存在: ',                       // lkDirNotExist
    '程序不存在: ',                       // lkAppNotExist
    '跟随系统'                            // lkLangSystem
  );

  EN_TEXT: array[TLangKey] of string = (
    'octopus-launch Settings',            // lkSettingsCaption
    'Trigger',                            // lkTrigger
    'Top edge',                           // lkTop
    'Bottom edge',                        // lkBottom
    'Left edge',                          // lkLeft
    'Right edge',                         // lkRight
    'Dwell delay (ms):',                  // lkDwellMs
    'Zone width (px):',                   // lkZonePx
    'Start with Windows',                 // lkAutoRun
    'Menu items',                         // lkMenuItems
    'Add item',                           // lkAdd
    'Add child',                          // lkAddChild
    'Add separator',                      // lkAddSep
    'Delete',                             // lkDelete
    'Move up',                            // lkMoveUp
    'Move down',                          // lkMoveDown
    'Name:',                              // lkName
    'Type:',                              // lkType
    'Target:',                            // lkTarget
    'Params:',                            // lkParams
    'Work dir:',                          // lkWorkDir
    'Browse...',                          // lkBrowse
    'Run as administrator',               // lkAdmin
    'Save',                               // lkSave
    'Cancel',                             // lkCancel
    'Application',                        // lkTypeApp
    'URL',                                // lkTypeUrl
    'Folder',                             // lkTypeDir
    'Separator',                          // lkTypeSep
    'New item',                           // lkNewItem
    'New child',                          // lkNewChild
    '(Untitled)',                         // lkUntitled
    'The menu is empty. Add items in Settings first.',  // lkEmptyMenu
    'Settings...',                        // lkTraySettings
    'Exit',                               // lkTrayExit
    'Language:',                          // lkLanguage
    'Programs|*.exe;*.lnk;*.bat;*.cmd|All files|*.*',   // lkProgFilter
    'Directory not found: ',              // lkDirNotExist
    'Program not found: ',                // lkAppNotExist
    'System'                              // lkLangSystem
  );

var
  FEn: Boolean = False;  // False=中文，True=English

// FPC 3.2.2 的 Windows 单元未声明，直接引入 kernel32
function GetUserDefaultUILanguage: WORD; stdcall;
  external kernel32 name 'GetUserDefaultUILanguage';

function L(Key: TLangKey): string;
begin
  if FEn then
    Result := EN_TEXT[Key]
  else
    Result := ZH_TEXT[Key];
end;

procedure SetLanguage(const ACode: string);
begin
  if ACode = 'system' then
    FEn := DetectDefaultLang = 'en'
  else
    FEn := ACode = 'en';
  if Assigned(OnLanguageChanged) then
    OnLanguageChanged;
end;

function DetectDefaultLang: string;
begin
  // 中文（简/繁）用 zh，其余一律 en
  if (GetUserDefaultUILanguage and $FF) = $04 then
    Result := 'zh'
  else
    Result := 'en';
end;

end.
