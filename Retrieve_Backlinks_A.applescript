property UseAliases : true
property AutoWiki_Links : true -- change to false for wiki links between double brackets, e.g. "[[link]]"
property theKind : "extension:md" -- the extension you will be looking for
property theDelimiter : "#### Linked mentions" -- Delimiter of choice. e.g. # Backlinks
property limit : 20 -- limit for the number of backlinks
property removeduplicates : false
property theSeparator : linefeed -- this will stand between the links. It can be just a space or some other random character.
property debug : true

if debug then
	tell application id "DNtp" to my PerformSmartRule(selection as list)
end if

on PerformSmartRule(theSources)
	tell application id "DNtp"
		if debug then
			set theSources to selection
		end if
		
		show progress indicator "Updating return links" with cancel button
		
		repeat with theSource in theSources
			step progress indicator (the name of theSource) as text
			set theList to my get_list(theSource)
			set theText to my replace_section(theSource, theList)
			set the plain text of theSource to theText
			
		end repeat
		
		hide progress indicator
		
	end tell
end PerformSmartRule

-- Handlers section
on get_list(theSource)
	tell application id "DNtp"
		set theName to name of theSource
		set theNameString to "\"" & theName & "\""
		set theDB to the database of theSource
		
		set theAliases to ""
		if UseAliases then set theAliases to aliases of theSource
		if theAliases is not "" then
			set theAliasesString to my trimtext(theAliases, ", ", "end")
			set theAliasesString to my trimtext(theAliases, " ", "end")
			set theAliasesString to my replaceText(theAliasesString, ", ", "\") OR (\"")
			set theSearchString to theNameString & " OR " & "(\"" & theAliasesString & "\")"
		else
			set theSearchString to theNameString
		end if
		
		set theSearchString to "name!=" & theName & " content: " & theSearchString & space & theKind
		log theSearchString
		set theList to {}
		set numLinks to 0
		set theRecords to search theSearchString in root of theDB
		
		repeat with theRecord in theRecords
			try
				set isExcluded to exclude from Wiki linking of theRecord
				if isExcluded then error 0 -- continue
				
				set theText to the plain text of theRecord
				set oldDelims to my text item delimiters
				set my text item delimiters to theDelimiter
				try
					set textContent to first text item of theText
				on error
					set textContent to theText
				end try
				set my text item delimiters to oldDelims
				
				-- check for the name
				set actuallyContains to name of theRecord is not theName and textContent contains theName
				
				-- fallback: check for the any alias
				if actuallyContains is false and UseAliases and theAliases is not "" then
					set oldDelims to my text item delimiters
					set my text item delimiters to ","
					repeat with sourceAlias in text items of theAliases
						set actuallyContains to textContent contains sourceAlias
						if actuallyContains then exit repeat
					end repeat
					set my text item delimiters to oldDelims
				end if
				
				if actuallyContains then
					set theRecordName to (name of theRecord) as text
					
					if AutoWiki_Links then
						set the end of theList to theRecordName & theSeparator
					else if theText contains "[[" & theName & "]]" then
						set the end of theList to "[[" & theRecordName & "]]" & theSeparator
					end if
					set numLinks to numLinks + 1
					if numLinks = limit then exit repeat
				end if
			end try
		end repeat
		
		considering numeric strings
			set theList to my sortlist(theList)
		end considering
		
		if removeduplicates then set theList to my removeDuplicateRecords(theList)
		
		return theList
		
	end tell
end get_list


on replace_section(theSource, theList)
	tell application id "DNtp"
		
		set theText to plain text of theSource
		
		try
			set OldDelimiter to AppleScript's text item delimiters
			set AppleScript's text item delimiters to theDelimiter
			set theDelimitedList to every text item of theText
			set AppleScript's text item delimiters to OldDelimiter
		on error
			set AppleScript's text item delimiters to OldDelimiter
		end try
		
		try
			set theText to item 1 of theDelimitedList
			set theText to my trimtext(theText, linefeed, "end")
			set numResults to count of items in theList
			if numResults > 0 then set theText to theText & linefeed & linefeed & theDelimiter & linefeed & linefeed & theList as text
			return theText
		end try
	end tell
end replace_section

on replaceText(theString, old, new)
	set {TID, text item delimiters} to {text item delimiters, old}
	set theStringItems to text items of theString
	set text item delimiters to new
	set theString to theStringItems as text
	set text item delimiters to TID
	return theString
end replaceText

on trimtext(theText, theCharactersToTrim, theTrimDirection)
	set theTrimLength to length of theCharactersToTrim
	if theTrimDirection is in {"beginning", "both"} then
		repeat while theText begins with theCharactersToTrim
			try
				set theText to characters (theTrimLength + 1) thru -1 of theText as string
			on error
				-- text contains nothing but trim characters
				return ""
			end try
		end repeat
	end if
	if theTrimDirection is in {"end", "both"} then
		repeat while theText ends with theCharactersToTrim
			try
				set theText to characters 1 thru -(theTrimLength + 1) of theText as string
			on error
				-- text contains nothing but trim characters
				return ""
			end try
		end repeat
	end if
	return theText
end trimtext

on sortlist(theList)
	set theIndexList to {}
	set theSortedList to {}
	repeat (length of theList) times
		set theLowItem to ""
		repeat with a from 1 to (length of theList)
			if a is not in theIndexList then
				set theCurrentItem to item a of theList as text
				if theLowItem is "" then
					set theLowItem to theCurrentItem
					set theLowItemIndex to a
				else if theCurrentItem comes before theLowItem then
					set theLowItem to theCurrentItem
					set theLowItemIndex to a
				end if
			end if
		end repeat
		set end of theSortedList to theLowItem
		set end of theIndexList to theLowItemIndex
	end repeat
	return theSortedList
end sortlist

on removeDuplicateRecords(inputList)
	set itemCount to count of items in inputList
	set outputList to {}
	repeat with anItem from 1 to itemCount
		set firstListItem to item anItem of inputList
		set occurrenceCount to 0
		repeat with anotherItem from 1 to count of items in outputList
			set secondListItem to item anotherItem of outputList
			if firstListItem is secondListItem then set occurrenceCount to occurrenceCount + 1
		end repeat
		if occurrenceCount = 0 then copy firstListItem to end of outputList
	end repeat
	
	return outputList
end removeDuplicateRecords
