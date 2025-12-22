--------------------------------------------
export type EggPacket<Assignable> = {
	Name: string,
	ID: number,
	RequestType: string,
	RequestAmount: number,
	Data: Assignable,
	State: number?,
	ThreadContext: number?
}

export type EggDef<Type> = {
	ModuleName: string,
	Limit: number,
	Type: string,
	Data: Type
}
--------------------------------------------
export type ModuleTable<Module> = {
	[string]: {Module}
}

export type Dict = {
	[any]: any
}

export type Field = {
	[string]: Dict
}
--[Packet Types]----------------------------
export type ModulePacket = {
	Path: string?,
	Success: boolean?
}

export type DataPacket = {
	any
}

export type CompletedPacket = DataPacket
--------------------------------------------
export type ThreadIncl = {
	Bevy: FieldTypes,
	Covy: BufferSink
}

export type ModuleSetupDef = {
	Nest: BurrowType,

	Modules: {
		[string]: string
	}
}
--------------------------------------------
export type ClutchInterface = {
	[string]: {
		Jobs: {[number]: EggPacket<any>},
		Callbacks: {[number]: (...any)->()}
	}
}

export type EggList = setmetatable<{
	[number]: BurrowType
}, {}> | {}
--------------------------------------------

export type FieldTypes = {
	Get: (Name: string) -> Dict,
	SyncBevy: (
		self: FieldTypes, 
		Packet: {
			Data: Field
	}) -> (),

	GetChanges: (self: FieldTypes) -> Field
}

export type BurrowType = {
	Egg: Thread,
	Nest: {Thread},
	CurrentEgg: number,
	BevyList: {
		[string]: Dict
	},

	AssignJob: <M>(
		self: BurrowType,
		EggDef: EggDef<M>
	) -> QuailHandle,

	OnComplete: (
		self: BurrowType,
		ModuleName: string,
		ID: number,
		fn: (...any) -> ()
	) -> (),

	InitBevy: (self: BurrowType) -> {[any]: any},
	NextEgg: (self: BurrowType) -> Thread,

	Clutch: ClutchInterface
}

export type QuailHandle = {
	Remove: (self: QuailHandle) -> (),
	Disable: (self: QuailHandle) -> (),
	Enable: (self: QuailHandle) -> (),

	Handle: EggPacket<any>
}

export type Nest = {
	NewNest: (self: Nest, EggAmount: number) -> BurrowType,
	AddModule: (self: Nest, pEgg: ModuleSetupDef) -> (),
	RemoveModule: (self: Nest, Name: string) -> (),

	Scheduler: (self: Nest) -> (),
	RoutineList: {() -> ()},
	ToggleScheduler: (self: Nest) -> (),

	NoInternalSchedule: boolean,

	Timer: number,
	EggList: EggList
}

return 1