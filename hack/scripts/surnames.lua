-- copy this file into /hack/scripts

local utils = require 'utils'
local validArgs = utils.invert({
  'patrilineal',
  'matrilineal',
  'list',
  'inherit_parents',
  'inherit_spouse',
  'no_output',
  'help'
})
local args = utils.processArgs({...}, validArgs)

local helpString = [====[

surnames
========

Arguments:

    -help                         show this help
    -patrilineal OR -matrilineal  type of inheritance line
    -list                         list greatest common patrilineal/matrilineal ancestors in console
    -inherit_parents              every citizen gets oldest patrilineal/matrilineal ancestor surname
    -inherit_spouse               every citizen gets husband's/wife's surname
    -no_output                    Hide output
]====]

printAllowed = true
if(args['no_output']) then
  printAllowed = false
end

if args.help then
  print(helpString)
  return
end

if not dfhack.world.isFortressMode() then
  return
end

local function condPrint(text)
  if(printAllowed) then
    print(text)
  end
end

if args['patrilineal'] and args['matrilineal'] then
  qerror('surnames: you can choose only one type of inheritance (patrilineal or matrilineal)')
  return
end

if ((args['patrilineal']==nil) and (args['matrilineal']==nil)) then
  qerror('surnames: you should choose type of inheritance (patrilineal or matrilineal)')
  return
end

if(args['patrilineal']) then
  paternal = true
else
  paternal = false
end

local function getFather(hf)
  father = nil
  for index, link in ipairs(hf.histfig_links) do
    if df.histfig_hf_link_fatherst:is_instance(link) then
      father = df.historical_figure.find(link.target_hf)
    end
  end
  return father
end

local function getMother(hf)
  mother = nil
  for index, link in ipairs(hf.histfig_links) do
    if df.histfig_hf_link_motherst:is_instance(link) then
      mother = df.historical_figure.find(link.target_hf)
    end
  end
  return mother
end

local function getSpouse(hf)
  spouse = nil
  for index, link in ipairs(hf.histfig_links) do
    if df.histfig_hf_link_spousest:is_instance(link) then
      spouse = df.historical_figure.find(link.target_hf)
    end
  end
  return spouse
end

local function findGreatestAncestor(paternal,hf)
  for i = 1,1000 do -- no infinite loops possible
    if(paternal) then
      f = getFather(hf)
    else
      f = getMother(hf)
    end
    if(f == nil) then
      return hf
    else
      hf = f
    end
  end
  return hf
end

local function assignSecondName(targetName, sourceName)
  targetName.words[0] = sourceName.words[0]
  targetName.words[1] = sourceName.words[1]
  targetName.parts_of_speech[0] = sourceName.parts_of_speech[0]
  targetName.parts_of_speech[1] = sourceName.parts_of_speech[1]
end

local function setHFSecondNames(paternal,hf,sourceName)
  for i = 1,1000 do -- no infinite loops possible
    if(paternal) then
      f = getFather(hf)
    else
      f = getMother(hf)
    end
    if(f == nil) then
      return
    else
      assignSecondName(hf.name, sourceName)
      hf = f
    end
  end
end



local ancestorIDS = {}

for k,v in pairs (df.global.world.units.active) do
  if dfhack.units.isCitizen(v)
  then
    local hf = df.historical_figure.find(v.hist_figure_id)

    local anc = findGreatestAncestor(paternal, hf)
    if(anc.id ~= hf.id) then
      if (ancestorIDS[anc.id]==nil) then
        ancestorIDS[anc.id] = {}
      end
      table.insert(ancestorIDS[anc.id],v)
    end
  end
end

function getName(unit)
  return dfhack.df2console(dfhack.TranslateName(dfhack.units.getVisibleName(unit)))
end

if args['list'] then
  sortedIds = {}
  for k,v in pairs (ancestorIDS) do
    table.insert(sortedIds,{id=k, number = #v})
  end
  table.sort(sortedIds, function(a,b) return a.number > b.number end)
  for i,v in ipairs (sortedIds) do
    local hf = df.historical_figure.find(v.id)
    local suffix = " (alive)"
    if hf.died_year ~= -1 then
      suffix = " (d. "..hf.died_year..")"
    end
    condPrint(dfhack.df2console(dfhack.TranslateName(hf.name))..suffix.." has "..v.number.." descendants")
  end
end

if(args['inherit_parents']) then
  for k,v in pairs (ancestorIDS) do
    local hf = df.historical_figure.find(k)
    for i,unit in pairs (v) do
      local unit_hf = df.historical_figure.find(unit.hist_figure_id)
      if(hf.id ~= unit.hist_figure_id) then
        setHFSecondNames(paternal, unit_hf, hf.name)
        condPrint(getName(unit)..' gets surname from oldest ancestor '..dfhack.df2console(dfhack.TranslateName((hf.name))))
        assignSecondName(unit.name, hf.name)
      end
    end
  end
end

if(args['inherit_spouse']) then
  for k,unit in pairs (df.global.world.units.active) do
    if dfhack.units.isCitizen(unit) then
      local hf = df.historical_figure.find(unit.hist_figure_id)
      local spouse = getSpouse(hf)
      if spouse and args['patrilineal'] and (unit.sex == 0) then -- female
        condPrint(getName(unit)..' gets surname from her husband '..dfhack.df2console(dfhack.TranslateName((spouse.name))))
        assignSecondName(unit.name, spouse.name)
        assignSecondName(hf.name, spouse.name)
      end

      if spouse and args['matrilineal'] and (unit.sex == 1) then -- male
        condPrint(getName(unit)..' gets surname from his wife '..dfhack.df2console(dfhack.TranslateName((spouse.name))))
        assignSecondName(unit.name, spouse.name)
        assignSecondName(hf.name, spouse.name)
      end
    end
  end
end
