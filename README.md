# 12/17/19 EDO Tuning
| A MuseScore 4 Plugin for tuning in 12/17/19 EDO based on [Bill Hails tuning plugin](https://github.com/musescore/MuseScore/blob/4.0.1/share/plugins/tuning/tuning.qml)

## Overview

This MuseScore 4 Retuner Plugin, written in QML, allows users to retune notes in 12, 17, or 19 EDO (Equal Division of the Octave) for both MS Basic and Muse Sounds Soundfonts. With this plugin, you can easily modify the tuning of your scores to explore alternative musical scales.

## Features

- Retune notes in 12, 17, or 19 EDO.
- Compatible with MSBasic and Muse Sounds Soundfonts.
- Choose between precalculated EDO cent offsets or define custom user-defined offsets.
- Save custom offsets in JSON format for future use.
- Interprets 17 EDO notation as described on [Wikipedia](https://en.wikipedia.org/wiki/17_equal_temperament#Notation)
- Interprets 19 EDO notation as described on [Wikipedia](https://en.wikipedia.org/wiki/19_equal_temperament#Notation)

## How to Use

1. **Download and Install:**
   - Download the plugin file on this page or from the releases section on [GitHub](https://github.com/jacobdill75/musescore-edo-tuning/releases).
   - Copy the plugin file to the MuseScore 4 [plugins directory](https://musescore.org/en/handbook/4/plugins#manage).

2. **Activate the Plugin:**
   - Launch MuseScore 4 on your system.
   - Access `Plugins > Manage Plugins`.
   - Select `EDO Tuning` and click `Enable`.

3. **Open the Plugin:**
   - Open your score in MuseScore 4.
   - Select the notes you want to retune. If no notes are selected, the plugin will retune all notes.
   - Navigate to `Plugins > Playback > EDO Tuning` in MuseScore 4.
   - Choose the "Retuner" option to run the plugin.

4. **Configure Retuning:**
   - In the plugin dialog, choose the desired EDO (12, 17, or 19) for default cent offsets.
   - Choose `Root Note` and `Pure Tone` from which to apply offsets.
   - Alternatively, define custom offsets in `Final Offsets` at the bottom.
   - Save custom offsets in JSON format for future use.

5. **Apply Changes:**
   - Click the "Apply" button to retune the selected notes according to the chosen configuration.

## Disclaimer

- For Mac users, the plugin is compatible with MuseScore 4.0.x; however, MuseScore 4.1.x currently crashes. Track that issue [here]().
- The EDO Tuning Plugin currently works for MuseScore 4.x on Windows.

## Support and Contributions

For issues, feature requests, or contributions, please visit the [GitHub repository](https://github.com/jacobdill75/musescore-edo-tuning). I welcome your feedback and contributions to improve this plugin.

Enjoy exploring new tunings, comment below with your compositions!
