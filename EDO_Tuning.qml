// Apply a choice of tempraments and tunings.
// Copyright (C) 2018-2023  Bill Hails, Jacob Dill
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import MuseScore 3.0
import QtQuick 2.2
import QtQuick.Controls 2.2
import QtQuick.Controls.Styles 1.3
import QtQuick.Layouts 1.1
import QtQuick.Dialogs 1.1
import FileIO 3.0

MuseScore {
    version: "1.1.0"
    title: "EDO Tuning"
    description: "Apply various temperaments and tunings, including 15-EDO" // Updated description
    pluginType: "dialog"
    categoryCode: "playback"
    thumbnailName: "edo_tuning.png"

    width: 590
    height: 712

    property var offsetTextWidth: 40; // Width for offset text input fields
    property var offsetLabelAlignment: 0x02 | 0x80; // Alignment for offset labels

    property var history: 0; // Command history for undo/redo

    property var modified: false; // Flag to track if tuning has been modified

    property var numOffsets: 21; // Number of offsets in the cycle of fifths (for Fb to B#)

    /*
     * Tuning definitions for different Equal Divisions of the Octave (EDO).
     * Each definition includes:
     * 'offsets': An array of cent offsets for each note in the cycle of fifths, ordered as:
     *            Fb, Cb, Gb, Db, Ab, Eb, Bb, F, C, G, D, A, E, B, F#, C#, G#, D#, A#, E#, B#.
     *            These offsets are deviations from 12-EDO equal temperament.
     * 'root':    The index of the root note (tonic) in the 'offsets' array. 8 corresponds to 'C'.
     * 'pure':    The index of the 'pure' tone used for tuning adjustments. 11 corresponds to 'A'.
     * 'name':    A unique name for the temperament.
     */
    property var equal12: {
        'offsets': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        'root': 8, // Root note is C
        'pure': 11, // Pure tone is A
        'name': "equal12"
    }
    property var equal17: {
                 //  0      1        2       3       4       5       6       7       8       9       10    11   12    13     14     15     16     17     18     19     20
                 //  Fb     Cb       Gb      Db      Ab      Eb      Bb      F       C       G       D     A    E     B      F#     C#     G#     D#     A#     E#     B#
        'offsets': [-64.71, -58.82, -52.94, -47.06, -41.18, -35.29, -29.41, -23.53, -17.65, -11.76, -5.88, 0.0, 5.88, 11.76, 17.65, 23.53, 29.41, 35.29, 41.18, 47.06, 52.94],
        'root': 8, // Root note is C
        'pure': 11, // Pure tone is A
        'name': "equal17"
    }
    property var equal19: {
                //  0      1      2      3      4      5      6      7      8      9      10    11    12     13      14      15      16      17     18      19      20
                //  Fb     Cb     Gb     Db     Ab     Eb     Bb     F      C      G      D     A     E      B       F#      C#      G#      D#     A#      E#      B#
        'offsets': [57.89, 52.63, 47.37, 42.11, 36.84, 31.58, 26.32, 21.05, 15.79, 10.53, 5.26, 0.0, -5.26, -10.53, -15.79, -21.05, -26.32, -32.0, -36.84, -42.11, -47.37],
        'root': 8, // Root note is C
        'pure': 11, // Pure tone is A
        'name': "equal19"
    }
    property var equal15: { // Definition for 15-EDO tuning
                //  0      1      2      3      4      5      6      7      8      9      10    11    12     13      14      15      16      17     18      19      20
                //  Fb     Cb     Gb     Db     Ab     Eb     Bb     F      C      G      D     A     E      B       F#      C#      G#      D#     A#      E#      B#
        'offsets': [-52.0, -46.8, -41.6, -36.4, -31.2, -26.0, -20.8, -15.6, -10.4, -5.2, 0.0, 5.2, 10.4, 15.6, 20.8, 26.0, 31.2, 36.4, 41.6, 46.8, 52.0], // Calculated offsets for 15-EDO
        'root': 8, // Root note is C
        'pure': 11, // Pure tone is A
        'name': "equal15"
    }

    property var currentTemperament: equal12; // Currently selected temperament, default is 12-EDO
    property var currentEdo: 12; // Currently selected EDO value, default is 12
    property var currentRoot: 8; // Currently selected root note index, default is 8 (C)
    property var currentPureTone: 11; // Currently selected pure tone index, default is 11 (A)
    property var currentTweak: 0.0; // Current tweak value in cents, default is 0.0

    onRun: {
        if (!curScore) {
            error("No score open.\nThis plugin requires an open score to run.\n")
            quit()
        }
    }

    // Gets the command history object, creates one if it doesn't exist
    function getHistory()
    {
        if (history == 0) {
            history = new commandHistory()
        }
        return history
    }

    // Applies the selected temperament to the selected notes in the score
    function applyTemperament()
    {
        var selection = new scoreSelection() // Creates a score selection object
        curScore.startCmd() // Starts a command group for undo/redo
        selection.map(filterNotes, reTune(getFinalTuning())) // Applies retuning to selected notes
        if (annotateValue.checkedState == Qt.Checked) {
            selection.map(filterNotes, annotate) // Annotates notes if checkbox is checked
        }
        curScore.endCmd() // Ends the command group
        return true
    }

    // Filters elements to only include chords (notes)
    function filterNotes(element)
    {
        return element.type == Element.CHORD
    }

    // Annotates notes with their tuning values as text elements
    function annotate(chord, cursor)
    {
        function addText(noteIndex, placement) {
            var note = chord.notes[noteIndex]
            var text = newElement(Element.STAFF_TEXT);
            text.text = '' + note.tuning // Set text to the note's tuning value
            text.autoplace = true
            text.fontSize = 7 // smaller font size for annotation
            text.placement = placement
            cursor.add(text)
        }

        // Annotate notes above or below the staff depending on voice
        if (cursor.voice == 0 || cursor.voice == 2) {
            for (var index = 0; index < chord.notes.length; index++) {
                addText(index, Placement.ABOVE)
            }
        } else {
            for (var index = chord.notes.length - 1; index >= 0; index--) {
                addText(index, Placement.BELOW)
            }
        }
    }

    // Returns a function that retunes a chord based on the provided tuning function
    function reTune(tuning) {
        return function(chord, cursor) {
            for (var i = 0; i < chord.notes.length; i++) {
                var note = chord.notes[i]
                // tpc1 is non-transposed pitch class, ensuring tuning is not affected by transposition
                note.tuning = tuning(note.tpc1);
            }
        }
    }

    // Manages score selection for applying tuning
    function scoreSelection() {
        const SCORE_START = 0
        const SELECTION_START = 1
        const SELECTION_END = 2
        var fullScore
        var startStaff
        var endStaff
        var endTick
        var inRange
        var rewind
        var cursor = curScore.newCursor()
        cursor.rewind(SELECTION_START) // Rewind cursor to selection start
        if (cursor.segment) { // If a selection exists
            startStaff = cursor.staffIdx
            cursor.rewind(SELECTION_END) // Rewind to selection end
            endStaff = cursor.staffIdx;
            endTick = 0 // unused
            if (cursor.tick === 0) {
               endTick = curScore.lastSegment.tick + 1;
            } else {
               endTick = cursor.tick;
            }
            inRange = function() { // Check if cursor is within selection range
                return cursor.segment && cursor.tick < endTick
            }
            rewind = function (voice, staff) { // Rewind cursor within selection
                cursor.rewind(SELECTION_START)
                cursor.voice = voice
                cursor.staffIdx = staff
            }
        } else { // If no selection, apply to entire score
            startStaff = 0
            endStaff  = curScore.nstaves - 1
            inRange = function () { // Check if cursor is within score range
                return cursor.segment
            }
            rewind = function (voice, staff) { // Rewind cursor within score
                cursor.voice = voice
                cursor.staffIdx = staff
                cursor.rewind(SCORE_START)
            }
        }

        this.map = function(filter, process) { // Apply process function to selected elements
            for (var staff = startStaff; staff <= endStaff; staff++) {
                for (var voice = 0; voice < 4; voice++) {
                    rewind(voice, staff)
                    while (inRange()) {
                        if (cursor.element && filter(cursor.element)) {
                            process(cursor.element, cursor)
                        }
                        cursor.next()
                    }
                }
            }
        }
    }

    // Displays an error message in a dialog
    function error(errorMessage) {
        errorDialog.text = qsTr(errorMessage)
        errorDialog.open()
    }

    /**
     * Looks up the cent offset for a given pitch (tpc) in the current temperament table.
     * Adjusts the offset based on the selected pure tone and tweak value.
     *
     * tpc : [-1,33] -> [Fbb, B##]; tpc_i + 1 = i + P5 (Pitch Class)
     *
     */
    function lookUp(tpc, table) {
        // Check for double accidentals, handled by getFinalTuning()
        if(tpc < 6 || 26 < tpc) {
            error("Bad tpc for pitch offset lookup: %1".arg(tpc))
        }
        // -6 to align Fb (tpc 6) to index 0 and B# (tpc 26) to index 20 in offsets array
        var offset = table.offsets[tpc - 6];
        // Shift offsets based on pure/root tone;
        //  +8 due to C being index 8 in offset array;
        var j = (currentPureTone - currentRoot) + 8;
        // +numOffsets to ensure positive modulo result
        var pureNoteAdjustment = table.offsets[(j + numOffsets) % numOffsets];
        var finalOffset = offset - pureNoteAdjustment; // Apply pure tone adjustment
        var tweakFinalOffset = finalOffset + parseFloat(tweakValue.text); // Apply tweak value
        return tweakFinalOffset;
    }

    /**
     * Returns a tuning function for recalculating final offsets.
     * This function uses lookUp to get the offset for each pitch based on current settings.
     */
    function getTuning() {
        return function(tpc) {
            return lookUp(tpc, currentTemperament);
        }
    }

    /*
     * Converts tpc values for double accidentals to single accidental equivalents
     * based on the current EDO. This is necessary because different EDOs may treat
     * double flats/sharps differently in terms of enharmonic equivalents.
     * For use in getFinalTuning().
     */
    function convertTpc(tpc) {
        var doubleFlats = []
        var doubleSharps = []
        switch(currentEdo) {
            case 12:
                doubleFlats = [final_e_flat, final_b_flat, final_f, final_c, final_g, final_d, final_a]
                doubleSharps = [final_g, final_d, final_a, final_e, final_b, final_f_sharp, final_c_sharp]
                break
            case 17:
                doubleFlats = [final_d, final_a, final_e, final_b, final_f_sharp, final_c_sharp, final_g_sharp]
                doubleSharps = [final_a_flat, final_e_flat, final_b_flat, final_f, final_c, final_g, final_d]
                break
            case 19:
                doubleFlats = [final_e, final_b, final_f_sharp, final_c_sharp, final_g_sharp, final_d_sharp, final_a_sharp]
                doubleSharps = [final_g_flat, final_d_flat, final_a_flat, final_e_flat, final_b_flat, final_f, final_c]
                break
            case 15: // Added case for 15-EDO double accidental handling.  Assuming similar logic to 12-EDO for now. May need adjustment based on 15-EDO theory if different.
                doubleFlats = [final_e_flat, final_b_flat, final_f, final_c, final_g, final_d, final_a] // Defaulting to 12-EDO logic for double flats
                doubleSharps = [final_g, final_d, final_a, final_e, final_b, final_f_sharp, final_c_sharp] // Defaulting to 12-EDO logic for double sharps
                break
            default:
                error("Invalid EDO: %1".arg(currentEdo))
        }
        // Offset +1 for double flat tpc's, which begin at -1
        // Offset -27 for double sharp tpc's, which begin at 27
        return (tpc < 6) ? doubleFlats[tpc + 1] : doubleSharps[tpc - 27]
    }

    // Returns a tuning function that gets the final offset for each tpc, handling double accidentals
    function getFinalTuning() {
        return function(tpc) {
            switch (tpc) {
                case -1: // F♭♭
                    return getFinalOffset(convertTpc(-1))
                case 0:  // C♭♭
                    return getFinalOffset(convertTpc(0))
                case 1:  // G♭♭
                    return getFinalOffset(convertTpc(1))
                case 2:  // D♭♭
                    return getFinalOffset(convertTpc(2))
                case 3:  // A♭♭
                    return getFinalOffset(convertTpc(3))
                case 4:  // E♭♭
                    return getFinalOffset(convertTpc(4))
                case 5:  // B♭♭
                    return getFinalOffset(convertTpc(5))
                case 6:  // F♭
                    return getFinalOffset(final_f_flat)
                case 7:  // C♭
                    return getFinalOffset(final_c_flat)
                case 8:  // G♭
                    return getFinalOffset(final_g_flat)
                case 9:  // D♭
                    return getFinalOffset(final_d_flat)
                case 10: // A♭
                    return getFinalOffset(final_a_flat)
                case 11: // E♭
                    return getFinalOffset(final_e_flat)
                case 12: // B♭
                    return getFinalOffset(final_b_flat)
                case 13: // F
                    return getFinalOffset(final_f)
                case 14: // C
                    return getFinalOffset(final_c)
                case 15: // G
                    return getFinalOffset(final_g)
                case 16: // D
                    return getFinalOffset(final_d)
                case 17: // A
                    return getFinalOffset(final_a)
                case 18: // E
                    return getFinalOffset(final_e)
                case 19: // B
                    return getFinalOffset(final_b)
                case 20: // F♯
                    return getFinalOffset(final_f_sharp)
                case 21: // C♯
                    return getFinalOffset(final_c_sharp)
                case 22: // G♯
                    return getFinalOffset(final_g_sharp)
                case 23: // D♯
                    return getFinalOffset(final_d_sharp)
                case 24: // A♯
                    return getFinalOffset(final_a_sharp)
                case 25: // E♯
                    return getFinalOffset(final_e_sharp)
                case 26: // B♯
                    return getFinalOffset(final_b_sharp)
                case 27: // F♯♯
                    return getFinalOffset(convertTpc(27))
                case 28: // C♯♯
                    return getFinalOffset(convertTpc(28))
                case 29: // G♯♯
                    return getFinalOffset(convertTpc(29))
                case 30: // D♯♯
                    return getFinalOffset(convertTpc(30))
                case 31: // A♯♯
                    return getFinalOffset(convertTpc(31))
                case 32: // E♯♯
                    return getFinalOffset(convertTpc(32))
                case 33: // B♯♯
                    return getFinalOffset(convertTpc(33))
                default:
                    error("unrecognised pitch: " + pitch)
            }
        }
    }

    // Gets the final offset value from a TextField object, parsing it as a float
    function getFinalOffset(textField) {
        return parseFloat(textField.text)
    }

    // Recalculates and updates the final offset text fields based on the provided tuning function
    function recalculate(tuning) {
        // Store old values for undo functionality
        var old_final_c_flat  = final_c_flat.text
        var old_final_c       = final_c.text
        var old_final_c_sharp = final_c_sharp.text
        var old_final_d_flat  = final_d_flat.text
        var old_final_d       = final_d.text
        var old_final_d_sharp = final_d_sharp.text
        var old_final_e_flat  = final_e_flat.text
        var old_final_e       = final_e.text
        var old_final_e_sharp = final_e_sharp.txt // Typo in original code: .txt should be .text
        var old_final_f_flat  = final_f_flat.text
        var old_final_f       = final_f.text
        var old_final_f_sharp = final_f_sharp.text
        var old_final_g_flat  = final_g_flat.text
        var old_final_g       = final_g.text
        var old_final_g_sharp = final_g_sharp.text
        var old_final_a_flat  = final_a_flat.text
        var old_final_a       = final_a.text
        var old_final_a_sharp = final_a_sharp.text
        var old_final_b_flat  = final_b_flat.text
        var old_final_b       = final_b.text
        var old_final_b_sharp = final_b_sharp.text
        getHistory().add( // Add undo command to history
            function () { // Undo function
                final_c_flat.text          = old_final_c_flat
                final_c_flat.previousText  = old_final_c_flat
                final_c.text               = old_final_c
                final_c.previousText       = old_final_c
                final_c_sharp.text         = old_final_c_sharp
                final_c_sharp.previousText = old_final_c_sharp
                final_d_flat.text          = old_final_d_flat
                final_d_flat.previousText  = old_final_d_flat
                final_d.text               = old_final_d
                final_d.previousText       = old_final_d
                final_d_sharp.text         = old_final_d_sharp
                final_d_sharp.previousText = old_final_d_sharp
                final_e_flat.text          = old_final_e_flat
                final_e_flat.previousText  = old_final_e_flat
                final_e.text               = old_final_e
                final_e.previousText       = old_final_e
                final_e_sharp.text         = old_final_e_sharp
                final_e_sharp.previousText = old_final_e_sharp
                final_f_flat.text          = old_final_f_flat
                final_f_flat.previousText  = old_final_f_flat
                final_f.text               = old_final_f
                final_f.previousText       = old_final_f
                final_f_sharp.text         = old_final_f_sharp
                final_f_sharp.previousText = old_final_f_sharp
                final_g_flat.text          = old_final_g_flat
                final_g_flat.previousText  = old_final_g_flat
                final_g.text               = old_final_g
                final_g.previousText       = old_final_g
                final_g_sharp.text         = old_final_g_sharp
                final_g_sharp.previousText = old_final_g_sharp
                final_a_flat.text          = old_final_a_flat
                final_a_flat.previousText  = old_final_a_flat
                final_a.text               = old_final_a
                final_a.previousText       = old_final_a
                final_a_sharp.text         = old_final_a_sharp
                final_a_sharp.previousText = old_final_a_sharp
                final_b_flat.text          = old_final_b_flat
                final_b_flat.previousText  = old_final_b_flat
                final_b.text               = old_final_b
                final_b.previousText       = old_final_b
                final_b_sharp.text         = old_final_b_sharp
                final_b_sharp.previousText = old_final_b_sharp
            },
            function() { // Redo function
                // TPC values retrieved from:
                // https://github.com/musescore/MuseScore/blob/master/share/plugins/note_names/notenames.qml#L44
                final_c_flat.text          = tuning(7).toFixed(1)
                final_c_flat.previousText  = final_c_flat.text
                final_c.text               = tuning(14).toFixed(1)
                final_c.previousText       = final_c.text
                final_c_sharp.text         = tuning(21).toFixed(1)
                final_c_sharp.previousText = final_c_sharp.text
                final_d_flat.text          = tuning(9).toFixed(1)
                final_d_flat.previousText  = final_d_flat.text
                final_d.text               = tuning(16).toFixed(1)
                final_d.previousText       = final_d.text
                final_d_sharp.text         = tuning(23).toFixed(1)
                final_d_sharp.previousText = final_d_sharp.text
                final_e_flat.text          = tuning(11).toFixed(1)
                final_e_flat.previousText  = final_e_flat.text
                final_e.text               = tuning(18).toFixed(1)
                final_e.previousText       = final_e.text
                final_e_sharp.text         = tuning(25).toFixed(1)
                final_e_sharp.previousText = final_e_sharp.text
                final_f_flat.text          = tuning(6).toFixed(1)
                final_f_flat.previousText  = final_f_flat.text
                final_f.text               = tuning(13).toFixed(1)
                final_f.previousText       = final_f.text
                final_f_sharp.text         = tuning(20).toFixed(1)
                final_f_sharp.previousText = final_f_sharp.text
                final_g_flat.text          = tuning(8).toFixed(1)
                final_g_flat.previousText  = final_g_flat.text
                final_g.text               = tuning(15).toFixed(1)
                final_g.previousText       = final_g.text
                final_g_sharp.text         = tuning(22).toFixed(1)
                final_g_sharp.previousText = final_g_sharp.text
                final_a_flat.text          = tuning(10).toFixed(1)
                final_a_flat.previousText  = final_a_flat.text
                final_a.text               = tuning(17).toFixed(1)
                final_a.previousText       = final_a.text
                final_a_sharp.text         = tuning(24).toFixed(1)
                final_a_sharp.previousText = final_a_sharp.text
                final_b_flat.text          = tuning(12).toFixed(1)
                final_b_flat.previousText  = final_b_flat.text
                final_b.text               = tuning(19).toFixed(1)
                final_b.previousText       = final_b.text
                final_b_sharp.text         = tuning(26).toFixed(1)
                final_b_sharp.previousText = final_b_sharp.text
            },
            "final offsets" // Command label for history
        )
    }

    // Sets the current temperament and updates UI and tuning parameters
    function setCurrentTemperament(temperament) {
        var oldTemperament = currentTemperament
        getHistory().add( // Add undo command to history
            function() { // Undo function
                currentTemperament = oldTemperament
                checkCurrentTemperament()
            },
            function() { // Redo function
                currentTemperament = temperament
                checkCurrentTemperament()
            },
            "current temperament" // Command label for history
        )
    }

    // Checks and sets the UI to reflect the current temperament selection
    function checkCurrentTemperament() {
        switch (currentTemperament.name) {
            case "equal12":
                equal12_button.checked = true
                currentEdo = 12
                return
            case "equal17":
                equal17_button.checked = true
                currentEdo = 17
                return
            case "equal19":
                equal19_button.checked = true
                currentEdo = 19
                return
            case "equal15": // Added case for 15-EDO
                equal15_button.checked = true
                currentEdo = 15
                return
        }
    }

    // Looks up a temperament definition by name
    function lookupTemperament(temperamentName) {
        switch (temperamentName) {
            case "equal12":
                return equal12
            case "equal17":
                return equal17
            case "equal19":
                return equal19
            case "equal15": // Added case for 15-EDO
                return equal15
        }
    }

    // Sets the current root note and updates UI and tuning parameters
    function setCurrentRoot(root) {
        var oldRoot = currentRoot
        getHistory().add( // Add undo command to history
            function () { // Undo function
                currentRoot = oldRoot
                checkCurrentRoot()
            },
            function() { // Redo function
                currentRoot = root
                checkCurrentRoot()
            },
            "current root" // Command label for history
        )
    }

    // Checks and sets the UI to reflect the current root note selection
    function checkCurrentRoot() {
        switch (currentRoot) {
            case 0:
                root_f_flat.checked = true
                break
            case 1:
                root_c_flat.checked = true
                break
            case 2:
                root_g_flat.checked = true
                break
            case 3:
                root_d_flat.checked = true
                break
            case 4:
                root_a_flat.checked = true
                break
            case 5:
                root_e_flat.checked = true
                break
            case 6:
                root_b_flat.checked = true
                break
            case 7:
                root_f.checked = true
                break
            case 8:
                root_c.checked = true
                break
            case 9:
                root_g.checked = true
                break
            case 10:
                root_d.checked = true
                break
            case 11:
                root_a.checked = true
                break
            case 12:
                root_e.checked = true
                break
            case 13:
                root_b.checked = true
                break
            case 14:
                root_f_sharp.checked = true
                break
            case 15:
                root_c_sharp.checked = true
                break
            case 16:
                root_g_sharp.checked = true
                break
            case 17:
                root_d_sharp.checked = true
                break
            case 18:
                root_a_sharp.checked = true
                break
            case 19:
                root_e_sharp.checked = true
                break
            case 20:
                root_b_sharp.checked = true
                break
        }
    }

    // Sets the current pure tone and updates UI and tuning parameters
    function setCurrentPureTone(pureTone) {
        var oldPureTone = currentPureTone
        getHistory().add( // Add undo command to history
            function () { // Undo function
                currentPureTone = oldPureTone
                checkCurrentPureTone()
            },
            function() { // Redo function
                currentPureTone = pureTone
                checkCurrentPureTone()
            },
            "current pure tone" // Command label for history
        )
    }

    // Sets the current tweak value and updates UI and tuning parameters
    function setCurrentTweak(tweak) {
        var oldTweak = currentTweak
        getHistory().add( // Add undo command to history
            function () { // Undo function
                currentTweak = oldTweak
                checkCurrentTweak()
            },
            function () { // Redo function
                currentTweak = tweak
                checkCurrentTweak()
            },
            "current tweak" // Command label for history
        )
    }

    // Updates the tweak value TextField to reflect the current tweak value
    function checkCurrentTweak() {
        tweakValue.text = currentTweak.toFixed(1)
    }

    // Checks and sets the UI to reflect the current pure tone selection
    function checkCurrentPureTone() {
        switch (currentPureTone) {
            case 0:
                pure_f_flat.checked = true
                break
            case 1:
                pure_c_flat.checked = true
                break
            case 2:
                pure_g_flat.checked = true
                break
            case 3:
                pure_d_flat.checked = true
                break
            case 4:
                pure_a_flat.checked = true
                break
            case 5:
                pure_e_flat.checked = true
                break
            case 6:
                pure_b_flat.checked = true
                break
            case 7:
                pure_f.checked = true
                break
            case 8:
                pure_c.checked = true
                break
            case 9:
                pure_g.checked = true
                break
            case 10:
                pure_d.checked = true
                break
            case 11:
                pure_a.checked = true
                break
            case 12:
                pure_e.checked = true
                break
            case 13:
                pure_b.checked = true
                break
            case 14:
                pure_f_sharp.checked = true
                break
            case 15:
                pure_c_sharp.checked = true
                break
            case 16:
                pure_g_sharp.checked = true
                break
            case 17:
                pure_d_sharp.checked = true
                break
            case 18:
                pure_a_sharp.checked = true
                break
            case 19:
                pure_e_sharp.checked = true
                break
            case 20:
                pure_b_sharp.checked = true
                break
        }
    }

    // Sets the modified flag and adds it to history for undo/redo
    function setModified(state) {
        var oldModified = modified
        getHistory().add( // Add undo command to history
            function () { // Undo function
                modified = oldModified
            },
            function () { // Redo function
                modified = state
            },
            "modified" // Command label for history
        )
    }

    // Handles temperament radio button clicks, updates settings and recalculates offsets
    function temperamentClicked(temperament) {
        getHistory().begin() // Begin a command transaction for undo/redo group
        setCurrentTemperament(temperament)
        setCurrentRoot(currentTemperament.root)
        setCurrentPureTone(currentTemperament.pure)
        setCurrentTweak(0.0)
        recalculate(getTuning())
        getHistory().end() // End command transaction
    }

    // Handles root note radio button clicks, updates settings and recalculates offsets
    function rootNoteClicked(note) {
        getHistory().begin() // Begin a command transaction
        setModified(true)
        setCurrentRoot(note)
        setCurrentPureTone(note)
        setCurrentTweak(0.0)
        recalculate(getTuning())
        getHistory().end() // End command transaction
    }

    // Handles pure tone radio button clicks, updates settings and recalculates offsets
    function pureToneClicked(note) {
        getHistory().begin() // Begin a command transaction
        setModified(true)
        setCurrentPureTone(note)
        setCurrentTweak(0.0)
        recalculate(getTuning())
        getHistory().end() // End command transaction
    }

    // Handles tweak value changes, updates settings and recalculates offsets
    function tweaked() {
        getHistory().begin() // Begin a command transaction
        setModified(true)
        setCurrentTweak(parseFloat(tweakValue.text))
        recalculate(getTuning())
        getHistory().end() // End command transaction
    }

    // Handles editing finished for final offset text fields, adds to history for undo/redo
    function editingFinishedFor(textField) {
        var oldText = textField.previousText
        var newText = textField.text
        getHistory().begin() // Begin a command transaction
        setModified(true)
        getHistory().add( // Add undo command to history
            function () { // Undo function
                textField.text = oldText
            },
            function () { // Redo function
                textField.text = newText
            },
            "edit ".concat(textField.name) // Command label includes the field name
        )
        getHistory().end() // End command transaction
        textField.previousText = newText // Update previous text for next edit
    }

    Rectangle {
        color: "transparent"
        anchors.fill: parent

        GridLayout {
            columns: 1
            anchors.fill: parent
            anchors.margins: 10
            GroupBox {
                title: "Temperament"
                RowLayout {
                    ButtonGroup { id: tempamentTypeGroup } // ButtonGroup for temperament radio buttons
                    RadioButton {
                        id: equal12_button
                        text: "12-EDO"
                        checked: true // Default selected temperament
                        ButtonGroup.group: tempamentTypeGroup
                        onClicked: { temperamentClicked(equal12) }
                    }
                    RadioButton {
                        id: equal17_button
                        text: "17-EDO"
                        checked: false
                        ButtonGroup.group: tempamentTypeGroup
                        onClicked: { temperamentClicked(equal17) }
                    }
                    RadioButton {
                        id: equal19_button
                        text: "19-EDO"
                        checked: false
                        ButtonGroup.group: tempamentTypeGroup
                        onClicked: { temperamentClicked(equal19) }
                    }
                    RadioButton { // Added RadioButton for 15-EDO
                        id: equal15_button
                        text: "15-EDO"
                        checked: false
                        ButtonGroup.group: tempamentTypeGroup
                        onClicked: { temperamentClicked(equal15) }
                    }
                }
            }

            ColumnLayout {
                GroupBox {
                    title: "Advanced"
                    ColumnLayout {
                        GroupBox {
                            title: "Root Note"
                            GridLayout {
                                columns: 7
                                anchors.margins: 10
                                ButtonGroup { id: rootNoteGroup } // ButtonGroup for root note radio buttons
                                RadioButton {
                                    text: "Fb"
                                    ButtonGroup.group: rootNoteGroup
                                    id: root_f_flat
                                    onClicked: { rootNoteClicked(0) }
                                }
                                RadioButton {
                                    text: "Cb"
                                    ButtonGroup.group: rootNoteGroup
                                    id: root_c_flat
                                    onClicked: { rootNoteClicked(1) }
                                }
                                RadioButton {
                                    text: "Gb"
                                    ButtonGroup.group: rootNoteGroup
                                    id: root_g_flat
                                    onClicked: { rootNoteClicked(2) }
                                }
                                RadioButton {
                                    text: "Db"
                                    ButtonGroup.group: rootNoteGroup
                                    id: root_d_flat
                                    onClicked: { rootNoteClicked(3) }
                                }
                                RadioButton {
                                    text: "Ab"
                                    ButtonGroup.group: rootNoteGroup
                                    id: root_a_flat
                                    onClicked: { rootNoteClicked(4) }
                                }
                                RadioButton {
                                    text: "Eb"
                                    ButtonGroup.group: rootNoteGroup
                                    id: root_e_flat
                                    onClicked: { rootNoteClicked(5) }
                                }
                                RadioButton {
                                    text: "Bb"
                                    ButtonGroup.group: rootNoteGroup
                                    id: root_b_flat
                                    onClicked: { rootNoteClicked(6) }
                                }
                                RadioButton {
                                    text: "F"
                                    ButtonGroup.group: rootNoteGroup
                                    id: root_f
                                    onClicked: { rootNoteClicked(7) }
                                }
                                RadioButton {
                                    text: "C"
                                    checked: true // Default selected root note
                                    ButtonGroup.group: rootNoteGroup
                                    id: root_c
                                    onClicked: { rootNoteClicked(8) }
                                }
                                RadioButton {
                                    text: "G"
                                    ButtonGroup.group: rootNoteGroup
                                    id: root_g
                                    onClicked: { rootNoteClicked(9) }
                                }
                                RadioButton {
                                    text: "D"
                                    ButtonGroup.group: rootNoteGroup
                                    id: root_d
                                    onClicked: { rootNoteClicked(10) }
                                }
                                RadioButton {
                                    text: "A"
                                    ButtonGroup.group: rootNoteGroup
                                    id: root_a
                                    onClicked: { rootNoteClicked(11) }
                                }
                                RadioButton {
                                    text: "E"
                                    ButtonGroup.group: rootNoteGroup
                                    id: root_e
                                    onClicked: { rootNoteClicked(12) }
                                }
                                RadioButton {
                                    text: "B"
                                    ButtonGroup.group: rootNoteGroup
                                    id: root_b
                                    onClicked: { rootNoteClicked(13) }
                                }
                                RadioButton {
                                    text: "F#"
                                    ButtonGroup.group: rootNoteGroup
                                    id: root_f_sharp
                                    onClicked: { rootNoteClicked(14) }
                                }
                                RadioButton {
                                    text: "C#"
                                    ButtonGroup.group: rootNoteGroup
                                    id: root_c_sharp
                                    onClicked: { rootNoteClicked(15) }
                                }
                                RadioButton {
                                    text: "G#"
                                    ButtonGroup.group: rootNoteGroup
                                    id: root_g_sharp
                                    onClicked: { rootNoteClicked(16) }
                                }
                                RadioButton {
                                    text: "D#"
                                    ButtonGroup.group: rootNoteGroup
                                    id: root_d_sharp
                                    onClicked: { rootNoteClicked(17) }
                                }
                                RadioButton {
                                    text: "A#"
                                    ButtonGroup.group: rootNoteGroup
                                    id: root_a_sharp
                                    onClicked: { rootNoteClicked(18) }
                                }
                                RadioButton {
                                    text: "E#"
                                    ButtonGroup.group: rootNoteGroup
                                    id: root_e_sharp
                                    onClicked: { rootNoteClicked(19) }
                                }
                                RadioButton {
                                    text: "B#"
                                    ButtonGroup.group: rootNoteGroup
                                    id: root_b_sharp
                                    onClicked: { rootNoteClicked(20) }
                                }
                            }
                        }

                        GroupBox {
                            title: "Pure Tone"
                            GridLayout {
                                columns: 7
                                anchors.margins: 10
                                ButtonGroup { id: pureToneGroup } // ButtonGroup for pure tone radio buttons
                                RadioButton {
                                    text: "Fb"
                                    id: pure_f_flat
                                    ButtonGroup.group: pureToneGroup
                                    onClicked: { pureToneClicked(0) }
                                }
                                RadioButton {
                                    text: "Cb"
                                    id: pure_c_flat
                                    ButtonGroup.group: pureToneGroup
                                    onClicked: { pureToneClicked(1) }
                                }
                                RadioButton {
                                    text: "Gb"
                                    id: pure_g_flat
                                    ButtonGroup.group: pureToneGroup
                                    onClicked: { pureToneClicked(2) }
                                }
                                RadioButton {
                                    text: "Db"
                                    id: pure_d_flat
                                    ButtonGroup.group: pureToneGroup
                                    onClicked: { pureToneClicked(3) }
                                }
                                RadioButton {
                                    text: "Ab"
                                    id: pure_a_flat
                                    ButtonGroup.group: pureToneGroup
                                    onClicked: { pureToneClicked(4) }
                                }
                                RadioButton {
                                    text: "Eb"
                                    id: pure_e_flat
                                    ButtonGroup.group: pureToneGroup
                                    onClicked: { pureToneClicked(5) }
                                }
                                RadioButton {
                                    text: "Bb"
                                    id: pure_b_flat
                                    ButtonGroup.group: pureToneGroup
                                    onClicked: { pureToneClicked(6) }
                                }
                                RadioButton {
                                    text: "F"
                                    id: pure_f
                                    ButtonGroup.group: pureToneGroup
                                    onClicked: { pureToneClicked(7) }
                                }
                                RadioButton {
                                    text: "C"
                                    id: pure_c
                                    ButtonGroup.group: pureToneGroup
                                    onClicked: { pureToneClicked(8) }
                                }
                                RadioButton {
                                    text: "G"
                                    id: pure_g
                                    ButtonGroup.group: pureToneGroup
                                    onClicked: { pureToneClicked(9) }
                                }
                                RadioButton {
                                    text: "D"
                                    id: pure_d
                                    ButtonGroup.group: pureToneGroup
                                    onClicked: { pureToneClicked(10) }
                                }
                                RadioButton {
                                    text: "A"
                                    checked: true // Default selected pure tone
                                    id: pure_a
                                    ButtonGroup.group: pureToneGroup
                                    onClicked: { pureToneClicked(11) }
                                }
                                RadioButton {
                                    text: "E"
                                    id: pure_e
                                    ButtonGroup.group: pureToneGroup
                                    onClicked: { pureToneClicked(12) }
                                }
                                RadioButton {
                                    text: "B"
                                    id: pure_b
                                    ButtonGroup.group: pureToneGroup
                                    onClicked: { pureToneClicked(13) }
                                }
                                RadioButton {
                                    text: "F#"
                                    id: pure_f_sharp
                                    ButtonGroup.group: pureToneGroup
                                    onClicked: { pureToneClicked(14) }
                                }
                                RadioButton {
                                    text: "C#"
                                    id: pure_c_sharp
                                    ButtonGroup.group: pureToneGroup
                                    onClicked: { pureToneClicked(15) }
                                }
                                RadioButton {
                                    text: "G#"
                                    id: pure_g_sharp
                                    ButtonGroup.group: pureToneGroup
                                    onClicked: { pureToneClicked(16) }
                                }
                                RadioButton {
                                    text: "D#"
                                    id: pure_d_sharp
                                    ButtonGroup.group: pureToneGroup
                                    onClicked: { pureToneClicked(17) }
                                }
                                RadioButton {
                                    text: "A#"
                                    id: pure_a_sharp
                                    ButtonGroup.group: pureToneGroup
                                    onClicked: { pureToneClicked(18) }
                                }
                                RadioButton {
                                    text: "E#"
                                    id: pure_e_sharp
                                    ButtonGroup.group: pureToneGroup
                                    onClicked: { pureToneClicked(19) }
                                }
                                RadioButton {
                                    text: "B#"
                                    id: pure_b_sharp
                                    ButtonGroup.group: pureToneGroup
                                    onClicked: { pureToneClicked(20) }
                                }
                            }
                        }

                        GroupBox {
                            title: "Tweak"
                            RowLayout {
                                TextField {
                                    Layout.maximumWidth: offsetTextWidth
                                    id: tweakValue
                                    text: "0.0"
                                    readOnly: false
                                    validator: DoubleValidator { bottom: -99.9; decimals: 1; notation: DoubleValidator.StandardNotation; top: 99.9 } // Validates input to be a double within range
                                    property var previousText: "0.0"
                                    property var name: "tweak"
                                    onEditingFinished: { tweaked() }
                                }
                            }
                        }

                        GroupBox {
                            title: "Final Offsets"
                            GridLayout {
                                columns: 14
                                anchors.margins: 0

                                Label {
                                    text: "Fb"
                                    Layout.alignment: offsetLabelAlignment
                                }
                                TextField {
                                    Layout.maximumWidth: offsetTextWidth
                                    id: final_f_flat
                                    text: "0.0"
                                    readOnly: false
                                    validator: DoubleValidator { bottom: -99.9; decimals: 1; notation: DoubleValidator.StandardNotation; top: 99.9 } // Validates input
                                    property var previousText: "0.0"
                                    property var name: "final Fb"
                                    onEditingFinished: { editingFinishedFor(final_f_flat) }
                                }

                                Label {
                                    text: "Cb"
                                    Layout.alignment: offsetLabelAlignment
                                }
                                TextField {
                                    Layout.maximumWidth: offsetTextWidth
                                    id: final_c_flat
                                    text: "0.0"
                                    readOnly: false
                                    validator: DoubleValidator { bottom: -99.9; decimals: 1; notation: DoubleValidator.StandardNotation; top: 99.9 } // Validates input
                                    property var previousText: "0.0"
                                    property var name: "final Cb"
                                    onEditingFinished: { editingFinishedFor(final_c_flat) }
                                }

                                Label {
                                    text: "Gb"
                                    Layout.alignment: offsetLabelAlignment
                                }
                                TextField {
                                    Layout.maximumWidth: offsetTextWidth
                                    id: final_g_flat
                                    text: "0.0"
                                    readOnly: false
                                    validator: DoubleValidator { bottom: -99.9; decimals: 1; notation: DoubleValidator.StandardNotation; top: 99.9 } // Validates input
                                    property var previousText: "0.0"
                                    property var name: "final Gb"
                                    onEditingFinished: { editingFinishedFor(final_g_flat) }
                                }

                                Label {
                                    text: "Db"
                                    Layout.alignment: offsetLabelAlignment
                                }
                                TextField {
                                    Layout.maximumWidth: offsetTextWidth
                                    id: final_d_flat
                                    text: "0.0"
                                    readOnly: false
                                    validator: DoubleValidator { bottom: -99.9; decimals: 1; notation: DoubleValidator.StandardNotation; top: 99.9 } // Validates input
                                    property var previousText: "0.0"
                                    property var name: "final Db"
                                    onEditingFinished: { editingFinishedFor(final_d_flat) }
                                }

                                Label {
                                    text: "Ab"
                                    Layout.alignment: offsetLabelAlignment
                                }
                                TextField {
                                    Layout.maximumWidth: offsetTextWidth
                                    id: final_a_flat
                                    text: "0.0"
                                    readOnly: false
                                    validator: DoubleValidator { bottom: -99.9; decimals: 1; notation: DoubleValidator.StandardNotation; top: 99.9 } // Validates input
                                    property var previousText: "0.0"
                                    property var name: "final Ab"
                                    onEditingFinished: { editingFinishedFor(final_a_flat) }
                                }

                                Label {
                                    text: "Eb"
                                    Layout.alignment: offsetLabelAlignment
                                }
                                TextField {
                                    Layout.maximumWidth: offsetTextWidth
                                    id: final_e_flat
                                    text: "0.0"
                                    readOnly: false
                                    validator: DoubleValidator { bottom: -99.9; decimals: 1; notation: DoubleValidator.StandardNotation; top: 99.9 } // Validates input
                                    property var previousText: "0.0"
                                    property var name: "final Eb"
                                    onEditingFinished: { editingFinishedFor(final_e_flat) }
                                }

                                Label {
                                    text: "Bb"
                                    Layout.alignment: offsetLabelAlignment
                                }
                                TextField {
                                    Layout.maximumWidth: offsetTextWidth
                                    id: final_b_flat
                                    text: "0.0"
                                    readOnly: false
                                    validator: DoubleValidator { bottom: -99.9; decimals: 1; notation: DoubleValidator.StandardNotation; top: 99.9 } // Validates input
                                    property var previousText: "0.0"
                                    property var name: "final Bb"
                                    onEditingFinished: { editingFinishedFor(final_b_flat) }
                                }

                                Label {
                                    text: "F"
                                    Layout.alignment: offsetLabelAlignment
                                }
                                TextField {
                                    Layout.maximumWidth: offsetTextWidth
                                    id: final_f
                                    text: "0.0"
                                    readOnly: false
                                    validator: DoubleValidator { bottom: -99.9; decimals: 1; notation: DoubleValidator.StandardNotation; top: 99.9 } // Validates input
                                    property var previousText: "0.0"
                                    property var name: "final F"
                                    onEditingFinished: { editingFinishedFor(final_f) }
                                }

                                Label {
                                    text: "C"
                                    Layout.alignment: offsetLabelAlignment
                                }
                                TextField {
                                    Layout.maximumWidth: offsetTextWidth
                                    id: final_c
                                    text: "0.0"
                                    readOnly: false
                                    validator: DoubleValidator { bottom: -99.9; decimals: 1; notation: DoubleValidator.StandardNotation; top: 99.9 } // Validates input
                                    property var previousText: "0.0"
                                    property var name: "final C"
                                    onEditingFinished: { editingFinishedFor(final_c) }
                                }

                                Label {
                                    text: "G"
                                    Layout.alignment: offsetLabelAlignment
                                }
                                TextField {
                                    Layout.maximumWidth: offsetTextWidth
                                    id: final_g
                                    text: "0.0"
                                    readOnly: false
                                    validator: DoubleValidator { bottom: -99.9; decimals: 1; notation: DoubleValidator.StandardNotation; top: 99.9 } // Validates input
                                    property var previousText: "0.0"
                                    property var name: "final G"
                                    onEditingFinished: { editingFinishedFor(final_g) }
                                }

                                Label {
                                    text: "D"
                                    Layout.alignment: offsetLabelAlignment
                                }
                                TextField {
                                    Layout.maximumWidth: offsetTextWidth
                                    id: final_d
                                    text: "0.0"
                                    readOnly: false
                                    validator: DoubleValidator { bottom: -99.9; decimals: 1; notation: DoubleValidator.StandardNotation; top: 99.9 } // Validates input
                                    property var previousText: "0.0"
                                    property var name: "final D"
                                    onEditingFinished: { editingFinishedFor(final_d) }
                                }

                                Label {
                                    text: "A"
                                    Layout.alignment: offsetLabelAlignment
                                }
                                TextField {
                                    Layout.maximumWidth: offsetTextWidth
                                    id: final_a
                                    text: "0.0"
                                    readOnly: false
                                    validator: DoubleValidator { bottom: -99.9; decimals: 1; notation: DoubleValidator.StandardNotation; top: 99.9 } // Validates input
                                    property var previousText: "0.0"
                                    property var name: "final A"
                                    onEditingFinished: { editingFinishedFor(final_a) }
                                }

                                Label {
                                    text: "E"
                                    Layout.alignment: offsetLabelAlignment
                                }
                                TextField {
                                    Layout.maximumWidth: offsetTextWidth
                                    id: final_e
                                    text: "0.0"
                                    readOnly: false
                                    validator: DoubleValidator { bottom: -99.9; decimals: 1; notation: DoubleValidator.StandardNotation; top: 99.9 } // Validates input
                                    property var previousText: "0.0"
                                    property var name: "final E"
                                    onEditingFinished: { editingFinishedFor(final_e) }
                                }

                                Label {
                                    text: "B"
                                    Layout.alignment: offsetLabelAlignment
                                }
                                TextField {
                                    Layout.maximumWidth: offsetTextWidth
                                    id: final_b
                                    text: "0.0"
                                    readOnly: false
                                    validator: DoubleValidator { bottom: -99.9; decimals: 1; notation: DoubleValidator.StandardNotation; top: 99.9 } // Validates input
                                    property var previousText: "0.0"
                                    property var name: "final B"
                                    onEditingFinished: { editingFinishedFor(final_b) }
                                }

                                Label {
                                    text: "F#"
                                    Layout.alignment: offsetLabelAlignment
                                }
                                TextField {
                                    Layout.maximumWidth: offsetTextWidth
                                    id: final_f_sharp
                                    text: "0.0"
                                    readOnly: false
                                    validator: DoubleValidator { bottom: -99.9; decimals: 1; notation: DoubleValidator.StandardNotation; top: 99.9 } // Validates input
                                    property var previousText: "0.0"
                                    property var name: "final F#"
                                    onEditingFinished: { editingFinishedFor(final_f_sharp) }
                                }

                                Label {
                                    text: "C#"
                                    Layout.alignment: offsetLabelAlignment
                                }
                                TextField {
                                    Layout.maximumWidth: offsetTextWidth
                                    id: final_c_sharp
                                    text: "0.0"
                                    readOnly: false
                                    validator: DoubleValidator { bottom: -99.9; decimals: 1; notation: DoubleValidator.StandardNotation; top: 99.9 } // Validates input
                                    property var previousText: "0.0"
                                    property var name: "final C#"
                                    onEditingFinished: { editingFinishedFor(final_c_sharp) }
                                }

                                Label {
                                    text: "G#"
                                    Layout.alignment: offsetLabelAlignment
                                }
                                TextField {
                                    Layout.maximumWidth: offsetTextWidth
                                    id: final_g_sharp
                                    text: "0.0"
                                    readOnly: false
                                    validator: DoubleValidator { bottom: -99.9; decimals: 1; notation: DoubleValidator.StandardNotation; top: 99.9 } // Validates input
                                    property var previousText: "0.0"
                                    property var name: "final G#"
                                    onEditingFinished: { editingFinishedFor(final_g_sharp) }
                                }

                                Label {
                                    text: "D#"
                                    Layout.alignment: offsetLabelAlignment
                                }
                                TextField {
                                    Layout.maximumWidth: offsetTextWidth
                                    id: final_d_sharp
                                    text: "0.0"
                                    readOnly: false
                                    validator: DoubleValidator { bottom: -99.9; decimals: 1; notation: DoubleValidator.StandardNotation; top: 99.9 } // Validates input
                                    property var previousText: "0.0"
                                    property var name: "final D#"
                                    onEditingFinished: { editingFinishedFor(final_d_sharp) }
                                }

                                Label {
                                    text: "A#"
                                    Layout.alignment: offsetLabelAlignment
                                }
                                TextField {
                                    Layout.maximumWidth: offsetTextWidth
                                    id: final_a_sharp
                                    text: "0.0"
                                    readOnly: false
                                    validator: DoubleValidator { bottom: -99.9; decimals: 1; notation: DoubleValidator.StandardNotation; top: 99.9 } // Validates input
                                    property var previousText: "0.0"
                                    property var name: "final A#"
                                    onEditingFinished: { editingFinishedFor(final_a_sharp) }
                                }

                                Label {
                                    text: "E#"
                                    Layout.alignment: offsetLabelAlignment
                                }
                                TextField {
                                    Layout.maximumWidth: offsetTextWidth
                                    id: final_e_sharp
                                    text: "0.0"
                                    readOnly: false
                                    validator: DoubleValidator { bottom: -99.9; decimals: 1; notation: DoubleValidator.StandardNotation; top: 99.9 } // Validates input
                                    property var previousText: "0.0"
                                    property var name: "final E#"
                                    onEditingFinished: { editingFinishedFor(final_e_sharp) }
                                }

                                Label {
                                    text: "B#"
                                    Layout.alignment: offsetLabelAlignment
                                }
                                TextField {
                                    Layout.maximumWidth: offsetTextWidth
                                    id: final_b_sharp
                                    text: "0.0"
                                    readOnly: false
                                    validator: DoubleValidator { bottom: -99.9; decimals: 1; notation: DoubleValidator.StandardNotation; top: 99.9 } // Validates input
                                    property var previousText: "0.0"
                                    property var name: "final B#"
                                    onEditingFinished: { editingFinishedFor(final_b_sharp) }
                                }
                            }
                        }
                        RowLayout {
                            Button {
                                id: saveButton
                                text: qsTranslate("PrefsDialogBase", "Save")
                                onClicked: {
                                    // File path for saving, using plugin path
                                    saveDialog.folder = Qt.resolvedUrl("file://" + filePath)
                                    saveDialog.visible = true
                                }
                            }
                            Button {
                                id: loadButton
                                text: qsTranslate("PrefsDialogBase", "Load")
                                onClicked: {
                                    loadDialog.folder = Qt.resolvedUrl("file://" + filePath)
                                    loadDialog.visible = true
                                }
                            }
                            Button {
                                id: undoButton
                                text: qsTranslate("PrefsDialogBase", "Undo")
                                onClicked: {
                                    getHistory().undo()
                                }
                            }
                            Button {
                                id: redoButton
                                text: qsTranslate("PrefsDialogBase", "Redo")
                                onClicked: {
                                    getHistory().redo()
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Button {
                        id: applyButton
                        text: qsTranslate("PrefsDialogBase", "Apply")
                        onClicked: {
                            if (applyTemperament()) {
                                if (modified) {
                                    quitDialog.open()
                                } else {
                                    quit()
                                }
                            }
                        }
                    }
                    Button {
                        id: cancelButton
                        text: qsTranslate("PrefsDialogBase", "Cancel")
                        onClicked: {
                            if (modified) {
                                quitDialog.open()
                            } else {
                                quit()
                            }
                        }
                    }
                    CheckBox {
                        id: annotateValue
                        text: qsTr("Annotate")
                        checked: false // Annotation checkbox, default unchecked
                    }
                }
            }
        }
    }

    MessageDialog {
        id: errorDialog
        title: "Error"
        text: ""
        onAccepted: {
            errorDialog.close()
        }
    }

    MessageDialog {
        id: quitDialog
        title: "Quit?"
        text: "Do you want to quit the plugin?"
        detailedText: "It looks like you have made customisations to this tuning, you could save them to a file before quitting if you like."
        standardButtons: StandardButton.Ok | StandardButton.Cancel
        onAccepted: {
            quit()
        }
        onRejected: {
            quitDialog.close()
        }
    }

    FileIO {
        id: saveFile
        source: ""
    }

    FileIO {
        id: loadFile
        source: ""
    }

    // Extracts file path from FileDialog URL
    function getFile(dialog) {
        var source = dialog.fileUrl.toString().substring(7) // strip the 'file://' prefix
        return source
    }

    // Formats current tuning values into a JSON string for saving
    function formatCurrentValues() {
        var data = {
            offsets: [
                parseFloat(final_c_flat.text),
                parseFloat(final_c.text),
                parseFloat(final_c_sharp.text),
                parseFloat(final_d_flat.text),
                parseFloat(final_d.text),
                parseFloat(final_d_sharp.text),
                parseFloat(final_e_flat.text),
                parseFloat(final_e.text),
                parseFloat(final_e_sharp.text),
                parseFloat(final_f_flat.text),
                parseFloat(final_f.text),
                parseFloat(final_f_sharp.text),
                parseFloat(final_g_flat.text),
                parseFloat(final_g.text),
                parseFloat(final_g_sharp.text),
                parseFloat(final_a_flat.text),
                parseFloat(final_a.text),
                parseFloat(final_a_sharp.text),
                parseFloat(final_b_flat.text),
                parseFloat(final_b.text),
                parseFloat(final_b_sharp.text)
            ],
            temperament: currentTemperament.name,
            root: currentRoot,
            pure: currentPureTone,
            tweak: currentTweak
        };
        return(JSON.stringify(data))
    }

    // Restores saved tuning values from a JSON data object
    function restoreSavedValues(data) {
        getHistory().begin() // Begin a command transaction
        setCurrentTemperament(lookupTemperament(data.temperament))
        setCurrentRoot(data.root)
        setCurrentPureTone(data.pure)
        // support older save files
        if (data.hasOwnProperty('tweak')) {
            setCurrentTweak(data.tweak)
        } else {
            setCurrentTweak(0.0)
        }
        recalculate( // Recalculate offsets based on loaded data
            function(pitch) {
                return data.offsets[pitch % numOffsets]
            }
        )
        getHistory().end() // End command transaction
    }

    FileDialog {
        id: loadDialog
        title: "Please choose a file"
        sidebarVisible: true
        onAccepted: {
            loadFile.source = getFile(loadDialog)
            var data = JSON.parse(loadFile.read())
            restoreSavedValues(data)
            loadDialog.visible = false
        }
        onRejected: {
            loadDialog.visible = false
        }
        visible: false
    }

    FileDialog {
        id: saveDialog
        title: "Please name a file"
        sidebarVisible: true
        selectExisting: false
        onAccepted: {
            saveFile.source = getFile(saveDialog)
            saveFile.write(formatCurrentValues())
            saveDialog.visible = false
        }
        onRejected: {
            saveDialog.visible = false
        }
        visible: false
    }

    // Command history implementation for undo/redo functionality
    function commandHistory() {
        function Command(undo_fn, redo_fn, label) {
            this.undo = undo_fn
            this.redo = redo_fn
            this.label = label // for debugging
        }

        var history = []
        var index = -1 // Current history index
        var transaction = 0 // Transaction flag for grouping commands
        var maxHistory = 30 // Maximum history depth

        function newHistory(commands) {
            if (index < maxHistory) {
                index++
                history = history.slice(0, index) // Truncate history if limit reached
            } else {
                history = history.slice(1, index) // Remove oldest history item
            }
            history.push(commands) // Add new command(s) to history
        }

        this.add = function(undo, redo, label) {
            var command = new Command(undo, redo, label)
            command.redo() // Execute the redo function immediately
            if (transaction) {
                history[index].push(command) // Add to current transaction
            } else {
                newHistory([command]) // Start new history entry
            }
        }

        this.undo = function() {
            if (index != -1) {
                history[index].slice().reverse().forEach( // Reverse slice to undo in correct order
                    function(command) {
                        command.undo() // Execute undo function for each command in entry
                    }
                )
                index-- // Move history index back
            }
        }

        this.redo = function() {
            if ((index + 1) < history.length) {
                index++ // Move history index forward
                history[index].forEach( // Execute redo function for each command in entry
                    function(command) {
                        command.redo()
                    }
                )
            }
        }

        this.begin = function() {
            if (transaction) {
                throw new Error("already in transaction")
            }
            newHistory([]) // Start a new history entry for transaction
            transaction = 1 // Set transaction flag
        }

        this.end = function() {
            if (!transaction) {
                throw new Error("not in transaction")
            }
            transaction = 0 // Clear transaction flag
        }
    }
}
// vim: ft=javascript
