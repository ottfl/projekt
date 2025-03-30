// #import "projekt_conf.typ": conf
#import "temp.typ": project
#import "@preview/wrap-it:0.1.0": wrap-content
#import "@preview/cetz:0.2.2"
// #show: doc => conf(
//   title: text(hyphenate: false)[IO-Verhalten und -Effizienz im Klima- und Wettermodell ICON],
//   authors: (
//     (
//       name: "Florian Ott",
//       affiliation: "Universität Hamburg, B.Sc. Informatik",
//       email: "florian.ott@studium.uni-hamburg.de"
//     ),
//   ),
//   abstract: [#lorem(20)],
//   doc
// )

#let todo(msg) = {
  [#text(fill: red, weight: "bold", size: 12pt)[TODO #msg]]
}

#show: project.with(
  supertitle: [_Projektbericht_],
  title: [IO-Verhalten und -Effizienz im Klima- und Wettermodell ICON],
  authors: (
    (
      name: "Florian Ott",
      affiliation: "Universität Hamburg, B.Sc. Informatik",
      email: "florian.ott@studium.uni-hamburg.de",
    ),
  ),
  abstract: [#lorem(100)], 
  logo: "UHH_Universität_Hamburg_Logo.png",
)

= Aufgabenstellung und Motivation <aufgabenstellung>

Grundlage dieses Berichts ist ein studentisches Projekt, welches in Kooperation mit dem Deutschen Klimarechenzentrum (DKRZ) durchgeführt wurde. Ziel war es, das Input/Output (IO)-Verhalten des Wetter- und Klimamodells ICON, spezifisch auf dem Supercomputer "Levante" des DKRZ, zu untersuchen. Das Hauptaugenmerk lag dabei auf der Untersuchung der zeitlichen Performance unter verschiedenen Parameterkombinationen.
#wrap-content(figure(image("computevsio.png"), caption: [Compute vs IO Development @argonne-io-intro], supplement: [Abb.]), align: top + right)[Dazu wurden verschiedenste Konfigurationen von IO-Modi und Parametern in ICON getestet und analysiert. Die Notwendigkeit der gezielten Betrachtung von IO ergibt sich aus der rapiden Entwicklung der Rechenleistung im Vergleich zu dem eher begrenzten Ausbau von IO-Bandbreite @argonne-io-intro. Dies kann zu einem Bottleneck seitens IO führen. Daher ist die Effizienz von IO im Zusammenspiel mit den eigentlichen Berechnungsvorgängen von zentraler Wichtigkeit, was jedoch ein Verständnis, auch spezifisch anwendungs- und systembezogener Natur, voraussetzt.] Das bisher begrenzte Wissen über IO betont dies besonders. Die Ergebnisse des Projekts sollen in diesem Bericht zusammengefasst und diskutiert werden. Zunächst werden Grundlagen zu ICON und IO in HPC erläutert, bevor die spezifischen Einstellungsmöglichkeiten in ICON und die verschiedenen IO-Modi vorgestellt werden. Darauf folgend werden das für die Messungen zugrundeliegende Experiment vorgestellt und die Ergebnisse diskutiert.

= Grundlagen <grundlagen>

== Das ICON-Modell <icon-descr>
#wrap-content(figure(image("erdeikosa.png"), caption: [Ikosahedrales Gitter @icon-icosa-symbol], supplement: [Abb.]), align: top + right)[ICON (_icosahedral non-hydrostatic_) ist ein Wettermodell, welches in einer Kooperation des Deutschen Wetterdienstes (DWD), dem Max-Planck-Institut für Meteorologie (MPI-M), dem Deutschen Klimarechenzentrum (DKRZ), dem Karlsruhe Institut für Technologie (KIT) und dem Center for Climate Systems Modeling (C2SM) entwickelt wurde. Vom DWD wird es für die operative Wettervorhersage genutzt, vom MPI-M für die Klimaforschung. Der Name leitet sich von der Eigenschaft ab, die Erde als icosahedrales Gitter und die Atmosphäre als nicht-hydrostatisch zu modellieren.] 
Dies soll die Betrachtung feinerer Maschenweiten im Gitter und somit eine genauere Berechnung und Vorhersage von Klima und Wetter ermöglichen @icon-wiki @icon-dwd. Die horizontale Maschenweite kann so auf bis zu 13km heruntergebrochen werden, bei 120 vertikalen Schichten der Atmosphäre mit einer Höhe bis zu 75km. Die Besonderheit des ikosahedralen Gitters ist die Aufteilung in 20 gleichseitige Dreiecke, welche immer feiner unterteilt werden können. ICON kann auch im Climate Limited-Area Mode (CLM) genutzt werden, wodurch die Fokussierung auf bestimmte Regionen möglich wird. So gibt es ICON-EU mit einer Maschenweite von 6,5km für Europa und ICON-D2 mit einer Maschenweite von 2,1km für Deutschland @icon-dwd.

Die hohe Auflösung, die mitunter hohe Anzahl an Variablen, die kurze Länge der Zeitintervalle sind Grundlage für die Notwendigkeit sehr feiner Berechnungen, was zu einem hohen Rechenaufwand führt. Dieser wird durch die Nutzung von Supercomputern und Parallelisierung der Berechnungen auf viele Prozessoren durch OpenMP (Open Multi-Processing - innerhalb eines Knotens) und mehrere Rechenknoten (mit Message Passing Interface - MPI) bewältigt. 
OpenMP wird verwendet, um mehrere Threads in einem Prozess zu starten. Bei der Nutzung von MPI werden mehrere Instanzen von ICON gestartet, wobei jede dieser einen eigenen Teil des Grids berechnet. Hybride Herangehensweisen sind ebenfalls möglich, bei denen sowohl OpenMP als auch MPI genutzt werden @icon-tutorial-mpim.
Zur Parallelisierung werden die Zellen des Grids in Blocks aufgeteilt, deren Länge innerhalb der Experimentskripte zu definieren ist. Diese können anschließend als 2D-Array nebeneinandergereiht werden. Weitere Infos folgen in @icon-settings[Kapitel].
Wie genau die IO-Operationen in ICON ablaufen, ist abhängig von der genauen Konfiguration durch die Anwendenden. Die Möglichkeiten dazu sollen im folgenden Kapiteln genauer beleuchtet werden.

== IO in HPC <io-hpc>
Die Herausforderung von IO in HPC besteht darin, dass im Kontrast zu herkömmlichem IO in Desktop-Computern Dateisysteme über viele Speichereinheiten verteilt sind, um die hohe Datenmenge zu bewältigen und benötigte Bandbreite zu realisieren. Auf Levante kommt das Dateisystem Lustre zum Einsatz, welches ermöglicht, einen POSIX-konformen Namespace über die Speichereinheiten zu verteilen. Für die Anwendenden wirkt es, als würden sie auf nur einer Speichereinheit arbeiten. 
#figure(image("lustre.png"), caption: [Lustre-Architektur @lustre], supplement: [Abb.]) <lustre-architecture>
Wie in @lustre-architecture zu sehen, besteht Lustre aus mehreren Komponenten, die auf verschiedenen Ebenen arbeiten. Auf den MDS (Meta Data Server) werden Metadaten der Dateien gespeichert, welche sich selbst auf OSS (Object Storage Server) befinden. Die Clients sind die Rechner, die auf das Dateisystem zugreifen. Eine weitere Besonderheit ist die Möglichkeit, Dateien in Stripes zu schreiben, also ein File auf mehrere OSTs zu verteilen. Dabei wird die Datei in gleichgroße Teile aufgeteilt und auf die OSTs geschrieben, entsprechend der RAID 0 Konfiguration. Dadurch kann die Bandbreite des Zugriffs auf eine Datei die Bandbreite des Zugriffs auf ein OST übersteigen @lustre.
Die Kommunikation zwischen den Komponenten erfolgt auf Levante über InfiniBand @levante-config. 

Für das Schreiben von Dateien gibt es in HPC verschiedene Optionen. 
- Die naive Lösung wäre, den Master Prozess eigenständig und allein die Datei schreiben zu lassen, nachdem Berechnungen über mehrere Prozesse oder Threads parallel durchgeführt wurden - wobei der Output dann ein Bottleneck darstellen würde. IO Operationen erfolgen immer nacheinander, somit *sequentiell*. 
- Alternativ kann das Schreiben von Dateien parallelisiert werden, indem jeder Prozess oder Thread eine eigene Datei schreibt (*File Per Process* - FPP). Dies wiederum kann jedoch zu einer hohen Anzahl an Dateien führen, was ebenso die Performance beeinträchtigen kann, da vor allem der Zugriff auf viele kleine Files unter Lustre ineffizient ist. Außerdem muss beachtet werden, dass auch für jeden dieser Files Metadaten gespeichert und gelesen werden müssen, was seinerseits unnötigen Overhead begünstigt. 
- Eine weitere Möglichkeit ist das Schreiben in *Shared Files*, bei dem mehrere Prozesse auf eine Datei schreiben. Dies kann die Anzahl der Dateien reduzieren und somit den Zugriff durch User vereinfachen. Allerdings ist die robuste Implementierung dieser Methode schwieriger als FPP.
- Darüber hinaus gibt es *Mischformen* zwischen den verschiedenen Optionen, zum Beispiel dass Shared Files pro Rechenknoten gebündelt werden. So liegt dann quasi eine File Per Node Konfiguration vor, die die Anzahl der Dateien reduziert, jedoch die Anzahl der Prozesse pro Datei erhöht @oak-ridge-io-intro.

= IO Einstellungsmöglichkeiten in ICON <icon-settings>

Die Steuerung des IO-Verhaltens in ICON erfolgt über verschiedene Parameter, welche in sogenannten "namelists" (nml) innerhalb der Experimentskripte festgelegt werden. Die genaue Dokumentation dazu ist in @namelist-overview zu finden. Zentral sind hier:
- `io_nml`:
  - `restart_write_mode`: Einstellung zum Schreibmodus der Restartfiles (Infos dazu folgen an anderer Stelle), 
- `parallel_nml`:
  - `nproma`: definiert Blocklänge, kann auch am Anfang des Skripts als Variable festgelegt werden
  - `num_io_procs`: definiert Anzahl dedizierter IO-Prozesse
  - `num_restart_procs`: definiert Anzahl dedizierter Restart-IO-Prozesse
  - `pio_type`: Festlegen von entweder klassisch asynchronem Schreiben (FPP) oder CDI-PIO (shared file)
- `run_nml`: 
  - `output`: Auswahl der Output-Komponenten, vor allem "nml" sei hier zu erwähnen, da so durch die `output_nml`-Namelist genauere Spezifikationen vorgenommen werden können
- `output_nml`:
  - `[domain]_varlist`: definiert die Variablen der entsprechenden Domäne, die geschrieben werden sollen
  - `output_filename`: definiert den Dateinamen
  - `stream_partitions_ml`: Anzahl der Prozesse, welche Output Files des Streams schreiben (insbesondere nützlich, wenn die einzelnen Files so groß sind, dass ein Prozess nicht in der Lage ist, sie zu schreiben, bis bereits ein neues Output File geschrieben werden muss)

Die entscheidendsten Einstellungen sind somit zunächst in der `output_nml` und der `parallel_nml` zu finden. Weitere exemplarisch wichtige Variablen, welche in den Runskripten der einzelnen Experimente zu finden sind, sind:
- `grid_refinement`: definiert die Maschenweite des Gitters
- `start_date`: Startdatum des Experiments
- `end_date`: Enddatum des Experiments
- `output_interval`: Intervall, in dem Ergebnisdaten geschrieben werden
- `file_interval`: Intervall, in dem eine neue Datei eröffnet wird, in welche die Ergebnisdaten geschrieben werden
- `restart_interval`: Intervall, in dem Restart-Dateien geschrieben werden
- `checkpoint_interval`: Intervall, in dem ein Checkpoint erstellt wird

Für jede `output_nml`-Nameliste wird ein File geschrieben, jeweils mit entsprechenden Intervallen, welche in der Namelist selbst definiert werden. Enthalten sind die in `[domain]_varlist` definierten Variablen. 
Diese Files werden je nach Einstellung der Intervalle in weitere Files unterteilt. Mehrere Outputs können in ein File geschrieben werden, nach erreichen des File Intervals wird eine neue Datei geschrieben.
Außerdem gibt es Restart Dateien, die das gesamte Set an Variablen enthalten. Diese werden zu jedem Checkpoint angelegt und können zur Wiederherstellung des Modells genutzt werden. Nach Erreichen des Restart Intervals wird der aktuelle Slurm (job scheduler auf Levante) Job beendet und ein neuer gestartet. Sowohl für Output als auch für Restart gibt es die Möglichkeit, einzelne Prozesse abzustellen, welche sich auf das Schreiben der entsprechenden Dateien konzentrieren.

= IO Modi in ICON <icon-io-modes>
Die verschiedenen Modi zum Schreiben und Lesen von Dateien in ICON ergeben sich aus den oben genannten Einstellungen.

== Seriell (Master Prozess) <seriell>
Die einfachste Variante ist, dass der Master Prozess alleine die Datei schreibt, nachdem alle Prozesse ihre Daten sammeln und an den Master schicken (in der Regel Prozess Rank 0). Dies ist jedoch ineffizient, da IO Operationen somit immer sequentiell ablaufen und die Worker auf das Schreiben der Daten warten müssen. Selbiges gilt für das Schreiben der Restart Files. Der Modus ergibt sich aus der Einstellung `num_io_procs = 0`. Die sehr einfache schematische Darstellung der Kommunikation zwischen Worker und IO Prozess ist in @serielles-io zu sehen.

#figure(
    grid(
        columns: 2,     // 2 means 2 auto-sized columns
        gutter: 2mm,    // space between columns
        image("s1.JPG"),
        image("s2.JPG"),
    ),
    caption: [serielles IO @io-in-climate-modelling],
    supplement: "Abb."
) <serielles-io>

== Klassisch asynchron (file per process) <fpp>
Eine weitere Möglichkeit ist das Schreiben von Dateien durch dedizierte IO Prozesse, welcher durch die Einstellung `num_io_procs > 0` aktiviert wird. Die Kommunikation zwischen Worker und IO Prozess ist in @fpp-io zu sehen. Die Worker schicken ihre Daten an die entsprechenden IO Prozesse, welche den Output in die entsprechenden Files schreiben. Jeder IO Prozess schreibt dabei in ein eigenes File, woher sich der Name "File Per Process" (FPP) ableitet. Dies kann jedoch zu einer hohen Anzahl an Dateien führen, was die Performance beeinträchtigen kann. Der Vorteil ist hier eine zeitlich wesentlich bessere Performance, jedoch ist es nach wie vor möglich, dass eine ungleiche Verteilung von Datenmengen auf Files zu bottlenecks führt. Ebenso werden datenintensive Jobs schnell von verhältnismäßig großen Mengen an Metadaten begleitet @farrell. Falls in regelmäßigen Abständen ein sehr großer File geschrieben werden muss und die Last trotzdem nur auf einem IO Prozess liegt, kann dies immer noch Wartezeiten der Worker bedingen (siehe @stream_partitioning-io).

#figure(
    grid(
        columns: 2,     // 2 means 2 auto-sized columns
        gutter: 2mm,    // space between columns
        image("s3.JPG"),
        image("s4.JPG"),
    ),
    caption: [serielles IO @io-in-climate-modelling],
    supplement: "Abb."
) <fpp-io>

Eine Option, welche Abhilfe schafft, ist das Partitionieren des Outputs. Dadurch werden große Outputs in kleinere Abschnitte unterteilt, welche jeweils in eigene Files geschrieben werden und somit auf mehrere IO Prozesse verteilt werden können. Die Funktionsweise ist in der rechten Abbildung in @stream_partitioning-io zu beobachten. In ICON funktioniert dies, indem die Outputzeit einen Offset bekommt. Ist ein Intervall von 4m für das Schreiben von Outputs vorgesehen, so wird bei einer Partitionierung mit 2 Streams ein Prozess nach 4, 12, 20, ... Minuten schreiben und der andere nach 8, 16, 24, ... Folglich entstehen jedoch mehrere kleine Dateien, statt eine große zusammenhängende, was die Nutzerfreundlichkeit erschwert. Dies geschieht mit `stream_partitions_ml` in der `output_nml`. Das Partitionieren wird für jedes Set an Variablen, also jeden Output Stream, individuell festgelegt.
Falls keine Unterteilung des Outputs vorgenommen wird, werden alle IO Prozesse, welche über die Anzahl der definierten Output Namelists hinausgehen, idlen.

#figure(
    grid(
        columns: 3,     // 2 means 2 auto-sized columns
        gutter: 2mm,    // space between columns
        image("s5.JPG"),
        image("s6.JPG"),
        image("s7.JPG"),
    ),
    caption: [Stream Partitioning @io-in-climate-modelling],
    supplement: "Abb."
) <stream_partitioning-io>

Parallel kann mit `num_restart_procs` die Anzahl der Prozesse festgelegt werden, die sich auf das Schreiben der Restart Files konzentrieren. Eine Übersicht der Restart Modi, welche in `restart_write_mode` festgelegt werden können:

- `sync`: PE (processing element) \#0 schreibt und liest Restart File. Alle anderen PEs warten. `num_restart_procs` MUSS auf 0 gesetzt werden, sonst gibt es Fehlermeldungen.
- `async`: Dedizierte PEs (definiert durch `num_restart_procs` > 0) schreiben Restart Files während Simulation weiterläuft. Lesen geschieht nur durch PE \#0.
- `joint procs multifile`: alle PEs schreiben Restart Files in dafür angelegtes Verzeichnis. Dieses Verzeichnis wird als Restart File verwendet. Alle PEs lesen aus diesem Verzeichnis parallel.
- `dedicated procs multifile`: Restart Daten werden von Workern in Buffer der Restart PEs gesendet. Worker PEs führen Berechnungen fort, Restart PEs schreiben die Files. Alle Worker PEs können gleichzeitig lesen 
- wird kein Modus spezifiziert, wird bei `num_restart_procs > 0` automatisch `async` gewählt, für einen Wert von 0 `sync` @namelist-overview.

== CDI-PIO (shared file) <shared>

#wrap-content(figure(image("shared_file.png", height: 6cm), caption: [Shared File IO], supplement: [Abb.]), align: top + right)[Des Weiteren hat sich die Methode etabliert, mehrere Prozesse auf eine Datei schreiben zu lassen, was als *Shared File IO* bezeichnet wird. Vorteil ist hierbei vor allem die erhöhte Benutzerfreundlichkeit, da bei FPP jeder Prozess eine eigene Datei schreibt, was die Handhabung erschwert. Erreicht wird dies durch das Striping von Files auf mehrere OSTs (siehe @io-hpc[Abschnitt]), sodass mehrere PEs in dem File schreiben können, jedoch logisch nur ein File existiert. Im Unterschied dazu wird auch bei dem partitionierten FPP für jede Partition ein komplett eigener File geschrieben. Idealerweise greift immer ein PE auf ein OST zu, bei mehreren PEs reduziert sich die Bandbreite bereits massiv, da zur Sicherung der Datenintegrität nicht mehrere PEs gleichzeitig schreiben können @farrell. Da CDI-PIO bislang in ICON eher experimentell implementiert ist, wurde es im Rahmen dieses Projekts nicht weiter betrachtet.] 

= Messungen <messungen>

Zentraler Bestandteil der vorliegenden Arbeit sind die Messungen, welche systematisch im Rahmen der Bearbeitung durchgeführt wurden und auf deren Grundlage anschließend eine grobe Empfehlung zur Wahl der Parameter bei der Konfiguration von ICON gegeben werden soll. 

== Methodik <messungen-methodik>

Zur zeitlichen Performanceanalyse wurden verschiedene Konfigurationen von IO-Modi und Parametern in ICON getestet. Die Messungen erfolgten auf dem Supercomputer "Levante" des DKRZ. Das zugrundeliegende Experiment ist das Testexperiment _exp.nh_dcmip_tc_52_r2b5_ und eine Version _exp.nh_dcmip_tc_52_r2b5_, d.h. der Tropenzyklon(tc)-Test mit 80km (r2b5) bzw. 40km (r2b6) Maschenweite zum non-hydrostatischen (nh) Dynamical Core Intercomparison Project (dcmip), welches dem Vergleich mehrerer Klimamodelle dient. Das Experiment-Skript wurde auf Empfehlung einer der Projektbetreuer*innen und Angestellten des DKRZ gewählt und wurde mehrfach für die Zwecke dieser Arbeit modifiziert #todo("git rep verlinken"). Unter anderem wurde die Möglichkeit des externen Inputs von Argumenten beim Aufruf des Skriptes geschaffen, um die Handhabbarkeit multipler Aufrufe des Skripts mit verschiedenen Einstellungen zu erleichtern. Die Liste der Output-Variablen, insgesamt 54 verschiedene, wurde größtenteils aus dem bestehenden Skript übernommen und nicht groß abgeändert.
Das Experiment berechnet einen Zeitraum von zehn Tagen, auch dies blieb unverändert. 
Aufgerufen wurde das Skript über ein eigens (rudimentär, da pragmatisch) geschriebenes Pythonskript (_mult_run.py_), in welchem Einstellungen für das aufzurufende Skript vorgenommen werden konnten, welche am Ende automatisch in das Log übertragen wurden. Ein weiterer Vorteil war die Möglichkeit, die Logs direkt in den entsprechenden Ordner der zugehörigen Experiment-Einstellungen zu verschieben, was die manuelle Zuordnung der Logs zu den Einstellungen erleichterte.
Nach ersten Tests erfolgte die Festlegung auf Parameterkombinationen, wobei zunächst IO und Restart bzw. Checkpoints separat betrachtet wurden. Zu dem Restart sei zu erwähnen, dass nur auf das Schreiben von Checkpoints eingegangen wird, nicht auf den eigentlichen Restart, da hierfür ein neuer Slurm-Job gestartet wird und die Erhebung der Daten für die Messungen dadurch für den Rahmen dieses Projekts zu aufwändig gewesen wäre. Dementsprechend ist dies ein Bereich, der sicherlich in anderen Projekten noch einmal genauer untersucht werden könnte.

Für die Untersuchung bezüglich des IO-Verhaltens wurden folgende Parameterkombinationen getestet:
- 80km Grid, 4min Output Intervall, 1 Knoten, davon je 0, 1, 2, 4, 8, 16, 32 IO Prozesse
- 80km Grid, 4min Output Intervall, 2 Knoten, davon je 0, 1, 2, 4, 8, 16, 32 IO Prozesse
- 80km Grid, 12min Output Intervall, 1 Knoten, davon je 0, 1, 2, 4, 8, 16, 32 IO Prozesse
- 80km Grid, 12min Output Intervall, 2 Knoten, davon je 0, 1, 2, 4, 8, 16, 32 IO Prozesse
- 40km Grid, 12min Output Intervall, 1 Knoten, davon je 0, 1, 2, 4, 8, 16, 32 IO Prozesse
- 40km Grid, 12min Output Intervall, 2 Knoten, davon je 0, 1, 2, 4, 8, 16, 32 IO Prozesse
- 40km Grid, 12min Output Intervall, 8 Knoten, davon je 0, 1, 2, 4, 8, 16, 32 IO Prozesse
Dabei wurde die Anzahl der IO Prozesse schrittweise erhöht, um die Auswirkungen auf die Performance zu untersuchen. Für alle Durchläufe wurde das Intervall des Schreibens von Checkpoints auf 12 Tage gesetzt, sodass keine geschrieben wurden und das Ergebnis nicht beeinflussen konnten.

Für die Untersuchung bezüglich des Schreibens von Checkpoints wurden folgende Parameterkombinationen getestet: 
- 80km Grid, 12m Checkpoint Intervall, 1 Knoten, davon je 0, 1, 2, 4, 8 Restart Prozesse
- 80km Grid, 12m Checkpoint Intervall, 2 Knoten, davon je 0, 1, 2, 4, 8 Restart Prozesse
- 80km Grid, 12m Checkpoint Intervall, 4 Knoten, davon je 0, 1, 2, 4, 8 Restart Prozesse
- 80km Grid, 12h Checkpoint Intervall, 1 Knoten, davon je 0, 1, 2, 4, 8 Restart Prozesse
- 80km Grid, 12h Checkpoint Intervall, 2 Knoten, davon je 0, 1, 2, 4, 8 Restart Prozesse
- 80km Grid, 12h Checkpoint Intervall, 2 Knoten, Modus "joint procs multifile"
- 80km Grid, 12h Checkpoint Intervall, 2 Knoten, davon je 0, 1, 2, 4, 8 Restart Prozesse, Modus "dedicated procs multifile"
- 40km Grid, 12h Checkpoint Intervall, 1 Knoten, davon je 0, 1, 2, 4, 8 Restart Prozesse
- 40km Grid, 12h Checkpoint Intervall, 2 Knoten, davon je 0, 1, 2, 4, 8 Restart Prozesse
Das Output Intervall wurde bei diesen Messungen auf 12 Tage gesetzt und überschritt somit den Experimentzeitraum, analog zum Vorgehen bei den IO Messungen. Soweit nicht anders angegeben war der angewendete Restart Modus immer "async", wobei bei 0 Restart Prozessen "sync" gewählt werden muss, da es sonst zu Fehlermeldungen kommt.

Um zu sehen, wie sich die Einstellungen von IO und Restart aufeinander auswirken und sich zusammen verhalten wurden abschließend verschiedene Kombinationen getestet:
- 80km Grid, 12m Output Intervall, 12h Checkpoint Intervall, 1 Knoten, 0 IO, je 1, 4, 8 Restart Prozesse
- 80km Grid, 12m Output Intervall, 12h Checkpoint Intervall, 1 Knoten, 1 IO, je 1, 4, 8 Restart Prozesse
- 80km Grid, 12m Output Intervall, 12h Checkpoint Intervall, 1 Knoten, 2 IO, je 1, 4, 8 Restart Prozesse
- 80km Grid, 12m Output Intervall, 12h Checkpoint Intervall, 1 Knoten, 4 IO, je 1, 4, 8 Restart Prozesse
- 80km Grid, 12m Output Intervall, 12h Checkpoint Intervall, 1 Knoten, 8 IO, je 1, 4, 8 Restart Prozesse
#todo("ggf 12m12m Messungen machen")

Die Auswertung erfolgt größtenteils auf Basis der Timer Reports innerhalb der Logfiles, welche anschließend automatisiert per Python-Skript #todo("quelle skript") ausgelesen und mit matplotlib visualisiert wurden. 
Außerdem wurde Darshan genutzt, um das IO-Verhalten der Prozesse während der Laufzeit zu analysieren. Darshan ist ein skalierbares Tool zur Auswertung von IO-Operationen, welches minimale Auswirkungen auf die Performance hat und einfach zur Runtime im Jobskript aktiviert werden kann. Dazu reicht das Einfügen von `LD_PRELOAD=/pfad/zu/darshan/lib/libdarshan.so` in den Header des Skripts. Während der Durchführung des Experiments kam es zu Problemen bei der Erstellung der Darshan Logs, weshalb nach einiger Recherche zur Ursache dessen die Loghints des Tools mit `DARSHAN_LOGHINTS=` deaktiviert wurden.
Zur Übersicht zu genutzter Rechenkapazität und Bandwidth erfolgte außerdem eine grobe Analyse der Logs aus ClusterCockpit, welches Daten aus allen laufenden Jobs aus Levante zusammenträgt und clusterseitig eine Analyse ermöglicht.

== Ergebnisse <messungen-ergebnisse>

=== Allgemein

=== IO

Wie zuvor beschrieben, wurde bei vorab durchgeführten Testläufen deutlich, dass die Anzahl der Streams, in die ein Output partitioniert wird, optimalerweise auf die Anzahl der IO Prozesse abgestimmt sein sollte. Dies wurde in den Messungen berücksichtigt, indem die Anzahl der Streams auf die Anzahl der IO Prozesse gesetzt wurde. Jeder zu schreibende Output ist für das Set an Variablen im Experiment auf einem 80km Grid etwa 254MB groß, auf einem 40km Grid etwa 1020MB - wie zu erwarten also eine knappe Vervierfachung bei einer Halbierung der Maschenweite. Die genaue Größe variiert je nach Anzahl der dezidierten Prozesse und Streams aufgrund anfallender Metadaten. Nachstehend abgebildet sind die Ergebnisse der Messungen auf dem 80km-Grid je mit 4min und 12min Output Intervall sowie 1 und 2 Knoten. Die Anzahl der IO Prozesse wurde schrittweise von 0 bis 32 erhöht. Eine kurze Erklärung zu den hier abgebildeten Graphen von links nach rechts:
- der erste Graph bildet die über alle Nicht-IO-Prozesse ermittelte "total"-Laufzeit, welche sich insgesamt mit nur sehr leichten Abweichungen mit der Experimentlaufzeit deckt, ab
- der zweite Graph zeigt die kumulierte Zeit, welche sowohl worker als auch IO-Prozesse im Durchschnitt für das Schreiben der Outputs benötigen
- der dritte Graph stellt die Geschwindigkeit des Schreibens der Outputdaten dar, einmal im Sinne der Übertragung an die IO Prozesse und einmal im Sinne des Schreibens auf die Ziel-Datei
Alle diese Daten wurden aus den Logs der Experimente extrahiert - leider wurden jedoch für die Durchläufe ohne spezifische IO PEs in den Logs keine Daten zu den Throughputs der IO Prozesse gespeichert, weshalb die Graphen an dieser Stelle leer blieben. Diese werden wenn möglich durch Erklärungen aus dem ClusterCockpit ergänzt.


Deutlich wird, dass das asynchrone IO, d.h. `num_io_procs > 0`, die Performance in jeder Konfiguration deutlich verbessert. Die Performancesteigerung ist dabei nicht linear, sondern zeigt eine Art Sättigungseffekt, der sich je nach konkreten Einstellungen ab einer bestimmten Anzahl von IO-Prozessen einstellt. Diese Beobachtung leitet sich auch aus den jeweils mittigen Graphen ab, in welchen die Zeit, welche sowohl worker als auch IO Procs mit dem Output verbringen, teilweise exponentiell abnimmt, entsprechend der sich verdoppelnden Anzahl der IO Prozesse. Somit wird der Zeitgewinn bei Hinzufügen weiterer IO Procs weiter gegen 0 gehen. Die Gesamtgröße des Outputs ist bei 12 Minuten Intervall knapp über 280 GiB groß, bei 4 Minuten sind es um die 860GiB. Zu sehen ist, dass die Laufzeit des Experiments auf 2 Knoten bei einem 4m-Intervall und synchronem IO im Vergleich zu der Version auf nur 1 Knoten zunächst ansteigt, was sich durch das sequentielle Schreiben und den Overhead erklären lässt, der sich durch die Kommunikation zwischen den beiden Knoten ergibt. Ein deutlicher Speedup ist erst ab mindestens zwei dezidierten IO PEs zu erkennen. Außerdem zeigt sich, dass aufgrund des steigenden Anteils der IO-Procs, welche nicht für die eigentliche Berechnung der Daten zur Verfügung stehen, an den Gesamtprozessen nach einem ersten Abfall der Laufzeit diese bei einer zu hohen Anzahl an IO Prozessen wieder ansteigt. Ebenfalls den Erwartungen entsprechend verdoppelt sich die write Zeit (mittiger Graph) bei Verdopplung der Rechenknoten bei sequentiellem IO, da dementsprechend doppelt so schnell Outputs geschrieben werden müssen, der Masterprozess aber immer noch das bottleneck darstellt. Gibt es jedoch IO Prozesse, so bleibt die Größendimension ihrer write Zeit pro Prozess etwa dieselbe, auch bei Verdopplung der Knoten. Interessant ist weiter, dass die Write-Geschwindigkeit (rechter Graph) immer einigermaßen konstant bleibt, die Übertragungszeit zu den IO Prozessen jedoch bei Erhöhung der Anzahl an Knoten sinkt - entsprechend der Limitation von Datenübertragung zwischen den Knoten. Weshalb sich die Übertragungszeit jedoch bei der zunehmende Zahl an IO Procs erhöht, ist nicht komplett klar. Möglicherweise wird der Transfer der Daten an die IO Procs dadurch behindert, dass, je mehr Prozesse parallel mit einem anderen Prozess kommunizieren wollen, die Bandbreite für jeden einzelnen sinkt. Dazu wäre ein noch genauerer Blick in den Quellcode von ICON oder auf Tools wie Score-P notwendig, um die zugrundeliegende Kommunikation zwischen Prozessen zu verstehen, die jedoch den Rahmen dieser Arbeit sprengen würde. Jedoch bleibt zu bemerken, dass die write-Geschwindigkeit, welche in den Logs angegeben wird, rechnerisch nicht zu der daneben angegebenen "time write" passt, sondern prinzipiell doppelt so hoch sein müsste. Vermutlich müssten also die Balken in den Diagrammen für die write-Geschwindigkeit halbiert verdoppelt werden, um die tatsächliche Geschwindigkeit darzustellen. Die get-Geschwindigkeit passt hingegen zu der angegebenen "time get" und ist somit korrekt. Auf einem Rechenknoten stehen 256 CPU-Cores zur Verfügung, wir rechnen jedoch nur auf 128 Prozessen, d.h. 2 Cores pro Prozess, eventuell ist das eine mögliche Begründung. #todo("es steht überall #restart procs im ersten graphen")
#figure(image("messungen/messzeiten_messungen_io_r2b5_4m_n1.png"),supplement: [Abb.]) <io-1>
#figure(image("messungen/messzeiten_messungen_io_r2b5_4m_n2.png"), supplement: [Abb.]) <io-2>
#figure(image("messungen/messzeiten_messungen_io_r2b5_12m_n1.png"), supplement: [Abb.]) <io-3>
#figure(image("messungen/messzeiten_messungen_io_r2b5_12m_n2.png"), supplement: [Abb.]) <io-4>
Ähnlich bilden sich die Beobachtungen ab, die man aus den Aufzeichnungen des ClusterCockpits ziehen kann. Die GFLOPs/s beginnen bei der 4 Knoten, 80km, 4min Version mit 0 IO Procs bei etwa 95 und steigern sich bis zu 4 IO Procs auf etwa 170, bevor sie langsam wieder abnehmen. Ähnlich verhält es sich bei der InfiniBand und Lustre Bandbreite (0,35 auf 1,2 GB/s und 0,35 auf 0,6 GB/s, respektive). Spannend ist, dass nur bei 0 IO Procs die Lustre BW genau der IB BW entspricht, ab 1 IO und aufsteigend ist die IB BW immer doppelt so hoch die die Lustre BW, vermutlich bedingt durch die Übertragung der worker an die IO Prozesse. Nur ein Knoten trägt zu der Lustre BW bei, es ist also ersichtlich, dass nur einer von zwei Knoten, nämlich eben jener, auf dem die IO Prozesse laufen, tatsächlich Files schreibt. Der andere Knoten hat dafür eine höhere Rechenleistung (mehr GFLOP/s).
Das primär interessante an den Darshan Reports ist die IO Performance bzgl. der POSIX Operationen. Laut Darshan nimmt in allen Konfigurationen die Schreibgeschwindigkeit mit steigender Anzahl an IO Procs insgesamt zu, jedoch scheint die Performance mit 1 IO Proc im Vergleich zum synchronen IO langsamer zu sein. Hauptprädiktor für die Geschwindigkeit ist die Anzahl der IO Prozesse, auch die Zahl der Knoten beeinflusst diese nicht allzu sehr. Bei 32 IO Procs beträgt sie bis zu 36000 MiB/s.
#figure(
    grid(
        columns: 2,     // 2 means 2 auto-sized columns
        gutter: 2mm,    // space between columns
        image("./messungen/darshan80kmIO.png"),
        image("./messungen/darshan40kmIO.png"),
    ),
    caption: [Darshan I/O Performance auf 80km und 40km Grid],
    supplement: "Abb."
) <darshan_io_perf>

Die nächsten zu betrachtenden Konfigurationen des Experiments basieren alle auf dem Grid mit 40km Maschenweite, mit einem Outputintervall von 12 Minuten und bei steigender Knotenanzahl (1, 2, 4, 8). Auch hier verlaufen der Großteil der Beobachtungen erwartungsgemäß. Die Entwicklungen der Laufzeiten bei Erhöhung der Zahl der IO Prozesse ist entsprechend der zunehmenden Zahl an Rechenknoten und damit -leistung deutlich sichtbarer desto mehr Knoten verwendet werden, da die Frequenz von IO Operationen durch höhere Rechengeschwindigkeit zunimmt. Bei 1 Knoten wird schon ab 1 IO Proc ein Plateau erreicht, bei 2 Knoten ab 2 IO Proc, bei 4 Knoten ab 4 Proc und bei 8 Knoten ist ab 16 Knoten keine große Verbesserung der Laufzeit mehr erwartbar. Spannenderweise nimmt die Laufzeit ohne dezidierten IO Prozess bei Erhöhung der Knotenanzahl erst ab und dann wieder leicht zu. Schaut man auf die durchschnittliche Zeit, die Prozesse mit dem Schreiben beschäftigt sind, wird auch sehr schnell die Bedeutung von IO als möglichem Bottleneck deutlich, da sich insbesondere von 4 auf 8 Knoten die Zeit fast verdoppelt. Schaut man sich die Write Zeit eines einzelnen IO Prozesses an, erkennt man, dass diese sich immer um die 3000 Sekunden bewegt, da sich weder die Anzahl der Outputs, noch die Größe der zu schreibenden Daten verändert. Das Schreiben braucht den Prozess immer konstant lang, nur müssen die worker PEs kumuliert immer länger auf das IO warten. Es scheint also sinnvoll, sich Gedanken darüber zu machen, wie hoch der benötigte Throughput des durchzuführenden Experiments ist und wie viele Prozesse benötigt werden, die sich explizit nur um das IO kümmern. Außerdem lässt sich feststellen, dass bei effizienter Konfiguration der Anzahl der IO Prozesse jedesmal eine Halbierung der Laufzeit erreicht werden kann, wenn man die Rechenleistung verdoppelt. Ein Indikator dafür könnte das Verhältnis zwischen wrt_output avg time der worker und derselben Zeit der IO Procs sein - wenn erstere mehr als die Hälfte der zweiteren beträgt, lohnt sich eine weitere Erhöhung der IO Prozesse. Auch in diesen Messungen kann wieder beobachtet werden, dass zumindest für 1 und 2 Knoten die Geschwindigkeit bei dem Übertragen der Daten auf die IO Prozesse bei steigender Zahl an IO Procs zunimmt, während die write-Geschwindigkeit begrenzt auf maximal 500 MB/s scheint.  #todo("noch nachreichen: 16, 32 Knoten aber mit mehr IO Procs")
#wrap-content(figure(image("./messungen/darshanHeatmapIO_r2b6_n1_32io.png"), caption: [Darshan Heatmap 40km Grid, 1 Knoten, 32 IO Procs], supplement: [Abb.]), align: top + right)[Die Beobachtungen aus Darshan zu den Messungen auf dem 80km Grid lassen sich vom Verlauf her übertragen, jedoch erreicht die IO Performance hier nur bis zu 15000 MiB/s bei 32 IO Prozessen. Rechts abgebildet ist eine Heatmap aus dem entsprechenden Darshan Log abgebildet, aus der sichtbar wird, dass 32 der 128 Prozesse regelmäßig Daten schreiben, jedoch häufiger in einem Leerlauf landen. Optimal wäre, wenn die IO Prozesse durchgängig laufen, da sonst unnötiges Overhead entsteht. Die markanteste Auffälligkeit bei den Logs von ClusterCockpit ist, dass mit zunehmenden Knoten die Lustre BW zunimmt.] 
#figure(image("messungen/messzeiten_messungen_io_r2b6_n1.png"),supplement: [Abb.]) <io-5>
#figure(image("messungen/messzeiten_messungen_io_r2b6_n2.png"), supplement: [Abb.]) <io-6>
#figure(image("messungen/messzeiten_messungen_io_r2b6_n4.png"), supplement: [Abb.]) <io-7>
#figure(image("messungen/messzeiten_messungen_io_r2b6_n8.png"), supplement: [Abb.]) <io-8>

Ein Problem kommt durch die Abweichung der Daten zwischen Darshan, CC und den Logs auf. Als Beispiel sei der Fall mit 4 Minuten Intervall, 80km Maschenweite, 1 Knoten und 8 IO Procs genannt. Darshan registriert im POSIX Modul 856,59 GiB geschrieben Dateien bei einer durchschnittlichen Geschwindigkeit von 6612,29 MiB/s. Aus den Logs ergeben sich kumuliert 854,26 GiB geschriebene Daten bei einer durchschnittlichen Schreibgeschwindigkeit von 480,93 MB/s #sym.approx 458,66 MiB/s pro Schreibvorgang. Selbst bei der Annahme, dass alle 8 IO PEs gleichzeitig geschrieben haben, ergeben sich so nur ~3669 MiB/s an Throughput. Gehen wir von etwa 855 GiB Gesamtoutput aus, ließen sich mit der Einschätzung aus Darshan so etwa 129 Sekunden Schreibzeit errechnen, mit dem Ergebnis aus den kumulierten Outputzeilen der Logs 233 Sekunden, bei um die 25 Minuten Gesamtlaufzeit des Experiments. Beides liegt weit von den durchschnittlich ~186 Sekunden entfernt, die jeder IO Prozess laut Timer Report mit wrt_output verbracht hat. Zieht man nun noch ClusterCockpit hinzu, beobachtet man eine Spitzenauslastung von etwa 1,25 GB/s für die Bandbreite auf InfiniBand und 0,6 GB/s Bandbreite aus Lustre selbst, wobei auch keiner der Werte mit den bisherigen wirklich zusammenpasst. Dementsprechend ist hier gut ein Trend erkennbar, eine tiefergehende Analyse und Vorhersage wird jedoch erschwert. Weiter dazu in @interpretation[Kapitel].

=== Checkpoints



=== Kombiniert

= Interpretation und Diskussion <interpretation>

- benötigt wäre eigentlich eine Analyse, wie viel KB einzelne Variablen haben, wie oft diese geschrieben werden, und anschließend lässt sich erst eine optimale Anzahl an IO Prozessen bestimmen
- zu schreibende Datenmenge und genutzte Anzahl an Rechenknoten muss bekannt sein um Prognosen zu treffen wie viele IO Prozesse man braucht um bottleneck zu umgehen
- könnte man hier einen Graph machen? zB 100 GB Output bei 8 Knoten
- 1 PE wird immer die gleiche Zeit zum schreiben für die gleiche Datenmenge benötigen, egal wie viele Rechenknoten genutzt werden
- entscheidend ist hier im Grunde, wie lange ein einzelner time step zu berechnen dauert und wie oft Outputs geschrieben werden sollen. wenn die worker länger zum berechnen zwischen den outputs brauchen als die IO procs zum schreiben gibt es kein bottleneck

= Notizen
- Lustre FPL, Striping für Benchmarking? Details zu Levante?
- Tools: Darshan
- Restart Write Modi
- siehe Tutorial S. 151 -> Datenstruktur Arrays Grid Blocks
- Kommunikation zwischen worker und IO/restart über mehrere Knoten - wie verteilen sich die Prozesse auf die Knoten?


= Anmerkungen
Der vorliegende Bericht wurde mit einem modifizierten Template für typst angefertigt @typst-temp. 

#bibliography("bibl.yml")