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
export type TypedList<K,V> = {
	[K]: V
}

export type Dict = TypedList<any, any>
export type ModuleTable<Module> = TypedList<string, TypedList<number, Module>>
export type Field = TypedList<string, Dict>
--[Packet Types]----------------------------
export type ModulePacket = {
	Path: string?,
	Success: boolean?
}

export type DataPacket = TypedList<any, any>

export type CompletedPacket = DataPacket
--------------------------------------------
export type ThreadInterface = {
	Bevy: FieldTypes,
	Covy: BufferSink
}

export type ModuleSetupDef = {
	Nest: BurrowType,

	Modules: TypedList<string, string>
}
--------------------------------------------
export type ClutchInterface = {
	[string]: {
		Jobs: TypedList<number, EggPacket<any>>,
		Callbacks: TypedList<number, (...any)->()>
	}
}

export type EggList = TypedList<number, BurrowType>
--------------------------------------------

export type FieldTypes = {
	Get: (Name: string) -> Dict,
	SyncBevy: (
		self: FieldTypes, 
		Packet: EggPacket<Field>
	) -> (),

	GetChanges: (self: FieldTypes) -> Field
}

export type BurrowType = {
	Egg: Thread,
	Nest: TypedList<number, Thread>,
	CurrentEgg: number,
	BevyList: Field,

	AssignJob: <M>(
		self: BurrowType,
		EggDef: EggDef<M>
	) -> QuailHandle,

	OnComplete: (
		self: BurrowType,
		Handle: EggPacket<any>,
		fn: <Type>(...Type) -> ()
	) -> (),

	InitBevy: (self: BurrowType) -> Dict,
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
	RoutineList: TypedList<number, () -> ()>,
	ToggleScheduler: (self: Nest) -> (),

	NoInternalSchedule: boolean,

	Timer: number,
	EggList: EggList
}

return 1