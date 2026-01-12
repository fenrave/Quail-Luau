export type InternalCase = {
    Default: any,
    [any]: any | (...any) -> any
}

type MetaCase = {
    __call: (Case: Case, Index: any, ...any?) -> ...any,
    __add: (Case: Case, ...any) -> Case
}
--------------------------------------------

export type Case = setmetatable<InternalCase, MetaCase>

--------------------------------------------
export type ThreadPacket<Assignable> = {
	Name: string,
	NestID: number,
	ID: number,
	RequestType: string,
	RequestAmount: number,
	Data: Assignable,
	State: number?,
	ThreadContext: number?
}

export type ThreadDef<Type> = {
	ModuleName: string,
	Limit: number,
	Data: Type
}
--------------------------------------------
export type TypedList<K,V> = {
	[K]: V
}

export type Dict = {
	[any]: any,
	Sync: (self: Dict) -> ()
}

export type ModuleTable<Module> = TypedList<string, TypedList<number, Module>>
export type Field = {
	[string]: Dict
}

export type Queue = TypedList<any, any>
export type Parallel = TypedList<number, TypedList<any, any>>

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

export type ModuleSetupDef = TypedList<string, string>

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
) -> TypedList<number, Thread> 

export type Indexer = {
	ID: number
}

--------------------------------------------
export type ClutchInterface = {
	[string]: {
		Jobs: TypedList<number, ThreadPacket<any>>,
		Callbacks: {TypedList<number, (...any)->()>}
	}
}

export type NestList = TypedList<number, BurrowType>
--------------------------------------------
export type FieldTypes = {
	Get: (Name: string, Meta: boolean?) -> Dict,
	SyncBevy: (
		self: FieldTypes,
		Packet: ThreadPacket<Field>
	) -> (),

	GetChanges: (self: FieldTypes) -> Field
}

export type BurrowType = {
	Thread: Thread,
	Nest: TypedList<number, Thread>,
	CurrentThread: number,
	BevyList: Field,
	InternalScheduler: SchedulerType,
	NestID: number,
	SchedType: string,
	AddModule: (self: BurrowType, SetupDef: ModuleSetupDef) -> (),

	BevyUpdate: ThreadPacket<any>,
	BevyRequest: ThreadPacket<any>,

	AssignJob: (
		self: BurrowType,
		EggDef: ThreadDef<any>
	) -> QuailHandle,

	OnComplete: (
		self: BurrowType,
		Handle: ThreadPacket<any>,
		fn: <Type>(...Type) -> ()
	) -> (),

	InitBevy: (self: BurrowType, Name: string) -> Dict,
	SyncBevies: (self: BurrowType) -> (),
	NextThread: (self: BurrowType) -> Thread,

	Clutch: ClutchInterface
}

export type QuailHandle = {
	Remove: (self: QuailHandle) -> (),
	Disable: (self: QuailHandle) -> (),
	Enable: (self: QuailHandle) -> (),
	OnComplete: (self: QuailHandle, fn: (...any) -> ()) -> (),

	Handle: ThreadPacket<any>
}

export type Quail = {
	NewNest: (
		self: Quail,
		ThreadAmount: number,
		SchedType: string?,
		CanAsync: boolean?
	) -> BurrowType,

	Scheduler: (self: Quail) -> (),
	RoutineList: TypedList<number, () -> ()>,

	ToggleScheduler: (self: Quail) -> (),

	NoInternalSchedule: boolean,

	ThreadLimit: number,
	Timer: number,
	NestList: NestList
}

export type Initializers = {
	ThreadCache: TypedList<number, Thread>,
	Receiver: (Thread: Thread) -> (),
	PseudoPacket: ThreadPacket<Parallel>,
	ReceiveQueue: {[number]: {Thread}},
	Queue: () -> (),
	CoroutineCase: Case,
	QueueCase: Case,
	Setup: (number) -> (),
	[string]: InitializerType
}

export type SchedulerList = TypedList<string, SchedulerType>
--------------------------------------------
local RequestEnum: TypedList<number, string> = {
	[1] = "MODULE",
	[2] = "SEND",
	[3] = "SYNC",
	[4] = "REQUESTSYNC"
}
--------------------------------------------
return {RequestEnum = RequestEnum}