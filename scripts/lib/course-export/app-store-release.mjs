export const APP_STORE_RELEASE_ID = "app-store-1.0";

// This is intentionally an explicit list rather than a collection filter: the
// ai-practice collection also contains an older, non-launch course.
export const APP_STORE_RELEASE_COURSE_IDS = Object.freeze([
  "a01-asking-about-products-and-services-a2",
  "a02-asking-for-directions-and-transit-information-a2",
  "a03-ordering-and-customizing-food-and-drinks-a2",
  "a04-explaining-what-you-need-while-shopping-a2",
  "a05-checking-in-and-providing-booking-information-a2",
  "a06-describing-symptoms-and-asking-basic-health-questions-b1",
  "a07-changing-a-reservation-or-appointment-b1",
  "a08-confirming-travel-and-booking-details-b1",
  "a09-returning-or-exchanging-a-product-b1",
  "a10-reporting-a-service-problem-and-negotiating-a-solution-b2",
  "a11-scheduling-rescheduling-and-canceling-plans-b1",
  "b01-introducing-yourself-a2",
  "b02-starting-small-talk-naturally-a2",
  "b03-showing-interest-and-asking-follow-up-questions-a2",
  "b04-keeping-a-conversation-going-and-changing-topics-smoothly-b1",
  "b05-asking-someone-to-repeat-or-slow-down-a2",
  "b06-clarifying-meaning-and-checking-understanding-b1",
  "b07-responding-naturally-to-news-and-personal-stories-b1",
  "b08-making-polite-requests-and-asking-for-favors-a2",
  "b09-refusing-politely-and-offering-alternatives-b2",
  "b10-apologizing-explaining-and-repairing-a-misunderstanding-b2",
  "c01-talking-work-study-current-life-a2",
  "c02-describing-where-i-live-a2",
  "c03-describing-my-daily-routine-a2",
  "c04-talking-about-my-weekend-and-free-time-a2",
  "c05-telling-a-recent-everyday-experience-b1",
  "c06-sharing-a-memorable-trip-or-experience-b1",
  "c07-explaining-preferences-and-an-ideal-lifestyle-b1",
  "c08-explaining-motivation-and-why-i-changed-a-habit-b1",
  "c09-talking-about-plans-goals-and-personal-change-b2",
  "d01-stating-an-opinion-clearly-and-explaining-why-b1",
  "d02-supporting-a-view-with-examples-and-personal-experience-b2",
  "d03-comparing-two-choices-and-explaining-a-preference-b1",
  "d04-discussing-advantages-disadvantages-and-trade-offs-b2",
  "d05-expressing-partial-agreement-conditions-and-exceptions-b2",
  "d06-responding-to-another-view-and-summarizing-your-position-b2",
]);

export const APP_STORE_RELEASE_DEFAULT_COURSE_ID = APP_STORE_RELEASE_COURSE_IDS[0];
