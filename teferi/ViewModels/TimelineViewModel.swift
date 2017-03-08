import Foundation
import RxSwift

///ViewModel for the TimelineViewController.
class TimelineViewModel
{
    //MARK: Fields
    private let isCurrentDay : Bool
    private let disposeBag = DisposeBag()
    
    private let timeService : TimeService
    private let appStateService : AppStateService
    private let timeSlotService : TimeSlotService
    private let editStateService : EditStateService
    
    //MARK: Initializers
    init(date: Date,
         timeService: TimeService,
         appStateService: AppStateService,
         timeSlotService: TimeSlotService,
         editStateService: EditStateService)
    {
        self.timeService = timeService
        self.appStateService = appStateService
        self.timeSlotService = timeSlotService
        self.editStateService = editStateService
        
        self.isCurrentDay = self.timeService.now.ignoreTimeComponents() == date.ignoreTimeComponents()
        self.date = date.ignoreTimeComponents()
        
        self.timeObservable =
            self.isCurrentDay ?
                Observable<Int>.timer(0, period: 10, scheduler: MainScheduler.instance) :
                Observable.empty()
    }
    
    func notifyEditingBegan(point: CGPoint, index: Int)
    {
        self.editStateService
            .notifyEditingBegan(point: point,
                                timeSlot: self.timelineItems[index].timeSlot)
    }
    
    //MARK: Properties
    let date : Date
    let timeObservable : Observable<Int>
    
    var currentDay : Date { return self.timeService.now }
    var isEditingObservable : Observable<Bool> { return self.editStateService.isEditingObservable }
    
    private(set) lazy var timeSlotCreatedObservable : Observable<Int> =
    {
        let createObservable =
            self.timeSlotService
                .timeSlotCreatedObservable
                .filter(self.timeSlotBelongsToThisDate)
                .map(self.toTimelineItemIndex)
        
        return createObservable
    }()
    
    private(set) lazy var refreshScreenObservable : Observable<Void> =
    {
        let updateObservable =
            self.timeSlotService
                .timeSlotUpdatedObservable
                .filter(self.timeSlotBelongsToThisDate)
                .map(self.refreshTimeSlotsFromService)
        
        let stateObservable =
            self.isCurrentDay ?
                Observable.empty() :
                self.appStateService
                    .appStateObservable
                    .filter(self.appIsActive)
                    .map(self.refreshTimeSlotsFromService)
        
        return Observable.of(stateObservable, updateObservable).merge()
    }()
    
    private(set) lazy var editViewObservable : Observable<Int> =
    {
        guard self.isCurrentDay else { return Observable<Int>.empty() }
        
        let observable =
            self.appStateService
                .appStateObservable
                .filter(self.appWasOpenedViaNotification)
                .map { _ in return self.timelineItems.count - 1 }
                .distinctUntilChanged()
        
        return observable
    }()
			
    private(set) lazy var timelineItems : [TimelineItem] =
    {
        let timeSlots = self.timeSlotService.getTimeSlots(forDay: self.date)
        let timelineItems = self.getTimelineItems(fromTimeSlots: timeSlots)
    
        //Creates an empty TimeSlot if there are no TimeSlots for today
        if self.isCurrentDay && timelineItems.count == 0
        {
            self.timeSlotService.addTimeSlot(withStartTime: self.timeService.now,
                                             category: .unknown,
                                             categoryWasSetByUser: false,
                                             tryUsingLatestLocation: false)
        }
    
        return timelineItems
    }()
    
    //MARK: Methods
    func calculateDuration(ofTimeSlot timeSlot: TimeSlot) -> TimeInterval
    {
        return self.timeSlotService.calculateDuration(ofTimeSlot: timeSlot)
    }

    private func appWasOpenedViaNotification(_ appState: AppState) -> Bool { return appState == .activeFromNotification }

    private func appIsActive(_ appState: AppState) -> Bool { return appState == .active }

    private func timeSlotBelongsToThisDate(_ timeSlot: TimeSlot) -> Bool { return timeSlot.startTime.ignoreTimeComponents() == self.date }
    
    private func refreshTimeSlotsFromService(_ ignore: Any) -> Void
    {
        let timeSlots = self.timeSlotService.getTimeSlots(forDay: self.date)
        self.timelineItems = self.getTimelineItems(fromTimeSlots: timeSlots)
    }
    
    private func toTimelineItemIndex(_ timeSlot: TimeSlot) -> Int
    {
        if let lastTimeSlot = self.timelineItems.last?.timeSlot
        {
            lastTimeSlot.endTime = Date()
        }
        
        let timeSlots = self.timelineItems.map { return $0.timeSlot } + [ timeSlot ]
        self.timelineItems = self.getTimelineItems(fromTimeSlots: timeSlots)

        return self.timelineItems.count - 1
    }
    
    private func isLastInPastDay(_ index: Int, count: Int) -> Bool
    {
        guard !self.isCurrentDay else { return false }
        
        let isLastEntry = count - 1 == index
        return isLastEntry
    }
    
    private func getTimelineItems(fromTimeSlots timeSlots: [TimeSlot]) -> [TimelineItem]
    {
        let count = timeSlots.count
        
        return timeSlots
            .enumerated()
            .reduce([TimelineItem]()) { accumulated, enumerated in
                
                let timeSlot = enumerated.element
                let n = enumerated.offset
                
                if timeSlot.category != .unknown,
                    let last = accumulated.last,
                    last.timeSlot.category == timeSlot.category
                {
                    return accumulated.dropLast() + [
                        last.withoutDurations(),
                        TimelineItem(timeSlot: timeSlot,
                                     durations: last.durations + [self.timeSlotService.calculateDuration(ofTimeSlot: timeSlot)],
                                     lastInPastDay: self.isLastInPastDay(n, count: count),
                                     shouldDisplayCategoryName: false)
                    ]
                }
                
                return accumulated + [
                    TimelineItem(timeSlot: timeSlot,
                                 durations: [self.timeSlotService.calculateDuration(ofTimeSlot: timeSlot)],
                                 lastInPastDay: self.isLastInPastDay(n, count: count),
                                 shouldDisplayCategoryName: true)
                ]
        }
    }
}
