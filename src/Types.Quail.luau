export type InternalCase = {
    Default: any,
    [any]: any | (...any) -> any
}

type MetaCase = {
    __call: (Case: Case, Index: any, ...any?) -> ...any,
    __add: (Case: Case, ...any) -> Case
}
------------------

export type Case = setmetatable<InternalCase, MetaCase>

--------------------------------------------
export type EggPacket<Assignable> = {
	Name: string,
	NestID: number,
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
export type Queue = TypedList<any, any>
export type Parallel = TypedList<number, Dict>

export type Schedulers = {
	Queue: Queue,
	Parallel: Parallel
}

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

export type SchedulerType = (
	self: SchedulerList,
	NewList: BurrowType,
	NestID: number
) -> ()

export type InitializerType = (
	self: Initializers,
	Burrow: BurrowType,
	Amount: number,
	ID: number
) -> TypedList<number, Thread> & AsyncHandler

export type Indexer = {
	ID: number
}

type Async = {
	__newindex: (
		List: Indexer,
		Index: string | number,
		Value: EggPacket<Parallel>
	) -> ()
}

export type AsyncHandler = setmetatable<{
		Threads: TypedList<number, Thread>,
		CurrentJob: EggPacket<Parallel>?
	} & Indexer,
	Async
>

export type AsyncThread = setmetatable<Indexer,Async>
--------------------------------------------
export type ClutchInterface = {
	[string]: {
		Jobs: TypedList<number, EggPacket<any>>,
		Callbacks: {TypedList<number, (...any)->()>}
	}
}

export type EggList = TypedList<number, BurrowType>
--------------------------------------------
export type FieldTypes = {
	Get: (Name: string, Meta: boolean?) -> Dict,
	SyncBevy: (
		self: FieldTypes,
		Packet: EggPacket<Field>
	) -> (),

	GetChanges: (self: FieldTypes) -> Field
}

export type BurrowType = {
	Egg: Thread,
	Nest: TypedList<number, Thread> & AsyncHandler,
	CurrentEgg: number,
	BevyList: Field,
	InternalScheduler: SchedulerType,
	NestID: number,
	SchedType: string,

	BevyUpdate: EggPacket<Field>,
	BevyRequest: EggPacket<nil>,

	AssignJob: (
		self: BurrowType,
		EggDef: EggDef<any>
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
	NewNest: (
		self: Nest,
		EggAmount: number,
		SchedType: string?,
		CanAsync: boolean?
	) -> BurrowType,

	AddModule: (self: Nest, pEgg: ModuleSetupDef) -> (),
	RemoveModule: (self: Nest, Name: string) -> (),

	Scheduler: (self: Nest) -> (),
	RoutineList: TypedList<number, () -> ()>,

	ToggleScheduler: (self: Nest) -> (),

	NoInternalSchedule: boolean,

	Timer: number,
	EggList: EggList
}

export type Initializers = {
	ThreadCache: TypedList<number, Thread>,
	AsyncHandlers: TypedList<number, TypedList<number, AsyncHandler>>,
	Receiver: (Thread: Thread) -> (),
	PseudoPacket: EggPacket<Parallel>,
	ReceiveQueue: {Thread},
	Queue: () -> (),
	CoroutineCase: Case
	,
	QueueCase: {
		[any]: (...any) -> ()
	},
	[string]: InitializerType
}

export type SchedulerList = TypedList<string, SchedulerType>
--------------------------------------------
local RequestEnum: TypedList<number, string> = {
	[1] = "Module",
	[2] = "Send",
	[3] = "Sync",
	[4] = "RequestSync"
}
--------------------------------------------
return {RequestEnum = RequestEnum}