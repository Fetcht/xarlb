Scriptname slalMCM extends SKI_ConfigBase
{MCM Menu for SLAnimLoader}

slalLoader Property Loader Auto
SexLabFramework Property SexLab Auto

bool Property verboseLogs = false Auto

; A JMap of {MCM option ID -> Anim ID string}
; This is only valid within a single animation page.  We rebuild it each
; time an animation page is opened.
int optionIDs = 0

function debugMsg(string msg)
  slalData.debugMsg(msg)
endFunction

int function GetVersion()
  return 2
endFunction

event OnConfigOpen()
  ; Reload the JSON data automatically each time the MCM is opened
  slalData.reloadData()

  Pages = getPageNames()
  optionIDs = JValue.retain(JMap.object())
endEvent

event OnConfigClose()
  JValue.release(optionIDs)
endEvent

event OnPageReset(string page)
  SetCursorFillMode(LEFT_TO_RIGHT)
  if page == ""
		LoadCustomContent("SLAL/SLAL SE.dds", 110, 50)
		return
	endIf
	UnloadCustomContent()

  if page == Pages[0]
    AddHeaderOption("$SLAL_ModName")
    AddHeaderOption("")
	AddTextOption("$SLAL_ModName2", "")
	AddEmptyOption()
	AddTextOption("$SLAL_ModName3", "")
	AddEmptyOption()
	AddEmptyOption()
	AddEmptyOption()

    AddTextOptionST("EnableAll", "$SLAL_EnableAll", "$SLAL_ClickHere")
    AddTextOptionST("DisableAll", "$SLAL_DisableAll", "$SLAL_ClickHere")
    AddTextOptionST("RegisterAnims", "$SLAL_RegisterAnimations", "$SLAL_ClickHere")
    AddTextOptionST("ReloadJSON", "$SLAL_ReloadJSON", "$SLAL_ClickHere")
    AddTextOptionST("RebuildAnimRegistry", "$SLAL_ResetAnimationRegistry", "$SLAL_ClickHere")
    AddTextOptionST("ReapplyJSON", "$SLAL_ReapplyJSON", "$SLAL_ClickHere")
    AddTextOptionST("AnimationCount", "$SLAL_CountAnimations", "$SLAL_ClickHere")
    AddToggleOptionST("VerboseLogs", "$SLAL_VerboseLogs", verboseLogs)
    return
  endIf

  AddTextOptionST("EnableAll", "$SLAL_EnableAll", "$SLAL_ClickHere")
  AddTextOptionST("DisableAll", "$SLAL_DisableAll", "$SLAL_ClickHere")
  AddTextOptionST("RegisterAnims", "$SLAL_RegisterAnimations", "$SLAL_ClickHere")
  AddEmptyOption()
  AddHeaderOption("$SLAL_Animations")
  AddHeaderOption("")

  int enableState = slalData.getEnableState()

  ; Must call Loader.PrepareFactory() before checking if animations are
  ; registered or not.
  Loader.PrepareFactory()

  JMap.clear(optionIDs)
  int anims = slalData.getAnimations()
  int catAnims = slalData.getCategoryAnims(page)
  int numAnims = JArray.count(catAnims)
  int n = 0
  while n < numAnims
    string animID = JArray.getStr(catAnims, n)
    int animInfo = JMap.getObj(anims, animID)
    addAnimationToggle(animInfo, enableState)
    n += 1
  endWhile
endEvent

string[] function getPageNames()
  int cats = slalData.getCategories()
  int catNames = JArray.sort(JMap.allKeys(cats))

  int numCats = JArray.count(catNames);
  string[] pageNames = PapyrusUtil.StringArray(numCats + 1)
  pageNames[0] = "$SLAL_GeneralOptions"
  int n = 0;
  while n < numCats
    pageNames[n + 1] = JArray.getStr(catNames, n)
    n += 1
  endWhile
  return pageNames
endFunction

function addAnimationToggle(int animInfo, int enableState)
  string animName = JMap.getStr(animInfo, "name")
  string animID = JMap.getStr(animInfo, "id")
  bool enabled = JMap.getInt(enableState, animID, 0)

  int optID
  int flags = OPTION_FLAG_NONE
  string error = JMap.getStr(animInfo, "error")
  if error != ""
    ; If we add a disabled toggle option then OnOptionHighlight() never
    ; gets called, and we can't show error info in the bottom option text.
    ; Threfore use a text option instead.
    optID = AddTextOption(animName, "X")
  else
    optID = AddToggleOption(animName, enabled)
  endIf

  JMap.setStr(optionIDs, optID, animID)
endFunction

int function getAnimInfoFromOptionID(int mcmOptionID)
  ; Look up the animID string in the optionIDs map, then look up the animInfo
  ; from that.
  ; (We could directly store animInfo ID in the optionIDs map, but it seems
  ; like then it would be easier to accidentally have subtle bugs if the JSON data
  ; is ever reloaded after building the optionIDs map.)
  string animID = JMap.getStr(optionIDs, mcmOptionID)
  return slalData.getAnimInfo(animID)
endFunction

event OnOptionSelect(int optID)
  int enableState = slalData.getEnableState()
  string animID = JMap.getStr(optionIDs, optID)
  if !animID
    return
  endIf

  bool enabled = JMap.getInt(enableState, animID, 0) as bool

  enabled = !enabled
  JMap.setInt(enableState, animID, enabled as int)

  SetToggleOptionValue(optID, enabled)
endEvent

event OnOptionHighlight(int optID)
  string animID = JMap.getStr(optionIDs, optID)
  if !animID
    return
  endIf

  int animInfo = slalData.getAnimInfo(animID)
  string error = JMap.getStr(animInfo, "error")
  if error != ""
    SetInfoText("Error" + " " + error)
    return
  endIf

  bool registered = Loader.isRegistered(animID)
  string animTags = JMap.getStr(animInfo, "tags")

  string msg = "Registered: " + registered
  msg += "\nTags: " + animTags
  SetInfoText(msg)
endEvent

state RegisterAnims
  event OnSelectST()
    SetOptionFlagsST(OPTION_FLAG_DISABLED)
    SetTextOptionValueST("$SLAL_Registering")

    int numRegistered
    if CurrentPage == Pages[0]
      numRegistered = Loader.registerAnimations()
    else
      numRegistered = Loader.registerCategoryAnimations(CurrentPage)
      ; Redraw the page, so the toggles will correctly reflect the registration state
      ForcePageReset()
    endIf

    SetTextOptionValueST("$SLAL_ClickHere")
    SetOptionFlagsST(OPTION_FLAG_NONE)
    ShowMessage("Registered " + numRegistered + " new animations", false)
  endEvent

  event OnHighlightST()
    SetInfoText("$SLAL_RegisterAnimationsInfo")
  endEvent
endState

state AnimationCount
  event OnSelectST()
    int enableState = slalData.getEnableState()
    int anims = slalData.getAnimations()
    string animID = JMap.nextKey(anims)
    int humanToRegister = 0
    int humanToUnregister = 0
    int creatureToRegister = 0
    int creatureToUnregister = 0
    while animID
      int animInfo = JMap.getObj(anims, animID)
      bool isCreature = JMap.hasKey(animInfo, "creature_race")
      bool enabled = JMap.getInt(enableState, animID) as bool
      bool registered = Loader.isRegistered(animID)
      if enabled
        if !registered
          if isCreature
            creatureToRegister += 1
          else
            humanToRegister += 1
          endIf
        endIf
      else
        if registered
          if isCreature
            creatureToUnregister += 1
          else
            humanToUnregister += 1
          endIf
        endIf
      endIf

      animID = JMap.nextKey(anims, animID)
    endWhile

    Loader.PrepareFactory()
    int humanCount = Loader.Slots.GetCount(false)
    int creatureCount = Loader.CreatureSlots.GetCount(false)
    debugMsg("SLAL: current creature count: " + creatureCount)

    int humanTotal = humanCount + humanToRegister - humanToUnregister;
    int creatureTotal = creatureCount + creatureToRegister - creatureToUnregister;
    ShowMessage("Human Animations: " + humanCount + " registered\n" + \
          humanToRegister + " to register, " + humanToUnregister + \
          " to unregister\nNew total: " + humanTotal + \
          "\nCreature Animations: " + creatureCount + " registered\n" + \
          creatureToRegister + " to register, " + creatureToUnregister + \
          " to unregister\nNew total: " + creatureTotal, false)
  endEvent
endState

state ReloadJSON
  event OnSelectST()
    string[] oldPages = getPageNames()
    int numErrors = slalData.reloadData()
    string[] newPages = getPageNames()

    if numErrors == 0
      ShowMessage("$SLAL_ReloadJSONSuccess", false)
    else
      ShowMessage("$SLAL_ReloadJSONErrors", false)
    endIf

    if oldPages != newPages
      ; Changing page names requires the user to close and re-open the MCM menu
      ; This has to be in a separate message box for translations to work properly.
      ; (Unfortunately you cannot concatenate separate translated strings.)
      ShowMessage("$SLAL_AnimCategoriesChanged", false)
    endIf
  endEvent

  event OnHighlightST()
    SetInfoText("$SLAL_ReloadJSONInfo")
  endEvent
endState

state RebuildAnimRegistry
  event OnSelectST()
    SetOptionFlagsST(OPTION_FLAG_DISABLED)
    SetTextOptionValueST("$SLAL_Resetting")
    SexLab.ThreadSlots.StopAll()
    SexLab.AnimSlots.Setup()
    SexLab.CreatureSlots.Setup()
    ShowMessage("$SLAL_ResetRegistryDone", false)
    Debug.Notification("$SLAL_ResetRegistryDone")
    SetTextOptionValueST("$SLAL_ClickHere")
    SetOptionFlagsST(OPTION_FLAG_NONE)
  endEvent

  event OnHighlightST()
    SetInfoText("$SLAL_ResetRegistryInfo")
  endEvent
endState

state ReapplyJSON
  event OnSelectST()
    SetOptionFlagsST(OPTION_FLAG_DISABLED)
    SetTextOptionValueST("$SLAL_Updating")

    ; Reload the JSON data before applying changes
    string[] oldPages = getPageNames()
    int numErrors = slalData.reloadData()
    string[] newPages = getPageNames()

    ; Update the settings in already registered animations
    Loader.updateJsonSettings()

    SetTextOptionValueST("$SLAL_ClickHere")
    SetOptionFlagsST(OPTION_FLAG_NONE)
  endEvent

  event OnHighlightST()
    SetInfoText("$SLAL_ReapplyJSONInfo")
  endEvent
endState

state EnableAll
  event OnSelectST()
    if CurrentPage == Pages[0]
      toggleAllAnims(true)
      ShowMessage("$SLAL_EnableAllDone", false)
    else
      toggleAllPageAnims(true)
    endIf
  endEvent

  event OnHighlightST()
    SetInfoText("$SLAL_EnableAllInfo")
  endEvent
endState

state DisableAll
  event OnSelectST()
    if CurrentPage == Pages[0]
      toggleAllAnims(false)
      ShowMessage("$SLAL_DisableAllDone", false)
    else
      toggleAllPageAnims(false)
    endIf
  endEvent

  event OnHighlightST()
    SetInfoText("$SLAL_DisableAllInfo")
  endEvent
endState

state VerboseLogs
  event OnSelectST()
    verboseLogs = !verboseLogs
    SetToggleOptionValueST(verboseLogs)
  endEvent

  event OnHighlightST()
    SetInfoText("$SLAL_VerboseLogsInfo")
  endEvent
endState

function toggleAllAnims(bool enable)
  int enableState = slalData.getEnableState()
  int anims = slalData.getAnimations()
  string animID = JMap.nextKey(anims)
  while animID
    JMap.setInt(enableState, animID, enable as int)
    animID = JMap.nextKey(anims, animID)
  endWhile
endFunction

function toggleAllPageAnims(bool enable)
  int enableState = slalData.getEnableState()
  int anims = slalData.getAnimations()
  int catAnims = slalData.getCategoryAnims(CurrentPage)
  int numAnims = JArray.count(catAnims)

  int n = 0
  int numRegistered = 0
  while n < numAnims
    string animID = JArray.getStr(catAnims, n)
    int animInfo = JMap.getObj(anims, animID)
    JMap.setInt(enableState, animID, enable as int)

    n += 1
  endWhile

  ForcePageReset()
endFunction