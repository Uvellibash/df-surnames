-- copy this file into /hack/scripts

local utils = require 'utils'
local validArgs = utils.invert({
'paternal-list',
'maternal-list',
'paternal-inheritance',
'maternal-inheritance',
'force-wives',
'force-husbands',
'help'
})
local args = utils.processArgs({...}, validArgs)

local helpString = [====[

surnames
========

Arguments:

    -help                      show this help
    -paternal-list             list greatest common paternal ancestors in console
    -maternal-list             list greatest common maternal ancestors in console
    -paternal-inheritance      every citizen gets oldest paternal ancestor second name
    -maternal-inheritance      every citizen gets oldest maternal ancestor second name
    -force-wives               force all wives to get their husband's second name
    -force-husbands            force all husbands to get their wive's second name

]====]

if args['paternal-inheritance'] and args['maternal-inheritance'] then
    print('you can choose only one type of inheritance')
    return
end

if args['force-wives'] and args['force-husbands'] then
    print('you can choose only one type of marriage tradition')
    return
end

if args.help then
  print(helpString)
  return
end

function getFather(hf)
    father = nil
    for index, link in ipairs(hf.histfig_links) do
        if df.histfig_hf_link_fatherst:is_instance(link) then
            father = df.historical_figure.find(link.target_hf)
        end
    end
    return father
end

function getMother(hf)
    mother = nil
    for index, link in ipairs(hf.histfig_links) do
        if df.histfig_hf_link_motherst:is_instance(link) then
            mother = df.historical_figure.find(link.target_hf)
        end
    end
    return mother
end

function getSpouse(hf)
    spouse = nil
    for index, link in ipairs(hf.histfig_links) do
        if df.histfig_hf_link_spousest:is_instance(link) then
            spouse = df.historical_figure.find(link.target_hf)
        end
    end
    return spouse
end

function findGreatestAncestor(paternal,hf)
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

function assignSecondName(targetName, sourceName)
    targetName.words[0] = sourceName.words[0]
    targetName.words[1] = sourceName.words[1]
    targetName.parts_of_speech[0] = sourceName.parts_of_speech[0]
    targetName.parts_of_speech[1] = sourceName.parts_of_speech[1]
end

function setHFSecondNames(paternal,hf,sourceName)
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


if(args['paternal-list'] or args['paternal-inheritance']) then
    paternal = true
else
    paternal = false
end

ancestorIDS = {}

for k,v in pairs (df.global.world.units.active) do
   if dfhack.units.isCitizen(v)
       then
            hf = df.historical_figure.find(v.hist_figure_id)

            anc = findGreatestAncestor(paternal, hf)
            if (ancestorIDS[anc.id]==nil) then
                ancestorIDS[anc.id] = {}
            end
            table.insert(ancestorIDS[anc.id],v)

            spouse = getSpouse(hf)

            if spouse and args['force-wives'] and (v.sex == 0) then -- female
                assignSecondName(v.name, spouse.name)
                assignSecondName(hf.name, spouse.name)
            end

            if spouse and args['force-husbands'] and (v.sex == 1) then -- male
                assignSecondName(v.name, spouse.name)
                assignSecondName(hf.name, spouse.name)
            end
   end
end

for k,v in pairs (ancestorIDS) do
    hf = df.historical_figure.find(k)

    if (args['paternal-list'] or args['maternal-list']) then
        suffix = " (alive)"
        if hf.died_year ~= -1 then
            suffix = " (d. "..hf.died_year..")"
        end
        print(#v.." "..dfhack.TranslateName(hf.name)..suffix)
    end

    if(args['paternal-inheritance'] or args['maternal-inheritance']) then
        for i,unit in pairs (v) do
            unit_hf = df.historical_figure.find(unit.hist_figure_id)
            setHFSecondNames(paternal, unit_hf, hf.name)
            assignSecondName(unit.name, hf.name)
        end
    end
end
