//For servers that can't do with any additional lag, set this to none in flightpacks.dm in subsystem/processing.
#define FLIGHTSUIT_PROCESSING_NONE 0
#define FLIGHTSUIT_PROCESSING_FULL 1

#define INITIALIZATION_INSSATOMS     0	//New should not call Initialize
#define INITIALIZATION_INNEW_MAPLOAD 1	//New should call Initialize(TRUE)
#define INITIALIZATION_INNEW_REGULAR 2	//New should call Initialize(FALSE)

#define INITIALIZE_HINT_NORMAL   0  //Nothing happens
#define INITIALIZE_HINT_LATELOAD 1  //Call LateInitialize
#define INITIALIZE_HINT_QDEL     2  //Call qdel on the atom

//type and all subtypes should always call Initialize in New()
#define INITIALIZE_IMMEDIATE(X) ##X/New(loc, ...){\
	..();\
	if(!(atom_flags & ATOM_FLAG_INITIALIZED)) {\
		args[1] = TRUE;\
		SSatoms.InitAtom(src, args);\
	}\
}

// Subsystem init_order, from highest priority to lowest priority
// Subsystems shutdown in the reverse of the order they initialize in
// The numbers just define the ordering, they are meaningless otherwise.

#define SS_INIT_EARLY			 16
#define SS_INIT_GARBAGE          15
#define SS_INIT_CHEMISTRY        14
#define SS_INIT_MATERIALS        13
#define SS_INIT_PLANTS           12
#define SS_INIT_ANTAGS           11
#define SS_INIT_CULTURE          10
#define SS_INIT_MISC             9
#define SS_INIT_CHAR_SETUP       8
#define SS_INIT_SKYBOX           7
#define SS_INIT_MAPPING          6
#define SS_INIT_CIRCUIT          5
#define SS_INIT_OPEN_SPACE       4
#define SS_INIT_ATOMS            3
#define SS_INIT_ICON_UPDATE      2
#define SS_INIT_MACHINES         1
#define SS_INIT_DEFAULT          0
#define SS_INIT_AIR             -1
#define SS_INIT_ASSETS          -2
#define SS_INIT_MISC_LATE       -3
#define SS_INIT_ALARM           -4
#define SS_INIT_SHUTTLE         -5
#define SS_INIT_OVERLAY         -6
#define SS_INIT_LIGHTING        -7
#define SS_INIT_BAY_LEGACY      -12
#define SS_INIT_TICKER          -20
#define SS_INIT_UNIT_TESTS      -100

// SS runlevels

#define RUNLEVEL_INIT 0
#define RUNLEVEL_LOBBY 1
#define RUNLEVEL_SETUP 2
#define RUNLEVEL_GAME 4
#define RUNLEVEL_POSTGAME 8

#define RUNLEVELS_DEFAULT (RUNLEVEL_SETUP | RUNLEVEL_GAME | RUNLEVEL_POSTGAME)

//! ## Overlays subsystem

///Compile all the overlays for an atom from the cache lists
// |= on overlays is not actually guaranteed to not add same appearances but we're optimistically using it anyway.
#define COMPILE_OVERLAYS(A)\
	do {\
		var/list/ad = A.add_overlays;\
		var/list/rm = A.remove_overlays;\
		if(LAZY_LENGTH(rm)){\
			A.overlays -= rm;\
			rm.Cut();\
		}\
		if(LAZY_LENGTH(ad)){\
			A.overlays |= ad;\
			ad.Cut();\
		}\
		A.atom_flags &= ~ATOM_FLAG_OVERLAY_QUEUED;\
	} while (FALSE)
