/**
 * @description Utility class for business day arithmetic. Provides methods to add
 * business days, count business days between dates, and check if a date is a
 * business day. Uses the default BusinessHours record when available; otherwise
 * falls back to a simple weekend-only exclusion.
 */
public with sharing class BusinessDayCalculator {

    // Cached default BusinessHours Id for the org
    private static Id defaultBusinessHoursId;
    private static Boolean businessHoursLoaded = false;

    /**
     * @description Loads the default BusinessHours record Id. Caches the result
     * so only one query is issued per transaction.
     * @return The Id of the default BusinessHours, or null if none exists
     */
    private static Id getDefaultBusinessHoursId() {
        if (!businessHoursLoaded) {
            List<BusinessHours> bhList = [
                SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1
            ];
            if (!bhList.isEmpty()) {
                defaultBusinessHoursId = bhList[0].Id;
            }
            businessHoursLoaded = true;
        }
        return defaultBusinessHoursId;
    }

    /**
     * @description Adds the specified number of business days to the start date.
     * Skips weekends (Saturday/Sunday). If default BusinessHours exist, uses
     * BusinessHours.nextStartDate to account for org-configured holidays.
     * @param startDate The date to start counting from
     * @param numDays The number of business days to add (must be >= 0)
     * @return The resulting date after adding business days
     */
    public static Date addBusinessDays(Date startDate, Integer numDays) {
        if (startDate == null || numDays == null || numDays < 0) {
            return startDate;
        }
        if (numDays == 0) {
            return startDate;
        }

        Id bhId = getDefaultBusinessHoursId();

        if (bhId != null) {
            return addBusinessDaysWithBusinessHours(bhId, startDate, numDays);
        }

        return addBusinessDaysWeekendOnly(startDate, numDays);
    }

    /**
     * @description Adds business days using the BusinessHours API, which respects
     * configured holidays and business hours.
     */
    private static Date addBusinessDaysWithBusinessHours(Id bhId, Date startDate, Integer numDays) {
        // Convert start date to a DateTime at midnight for BusinessHours API
        Datetime startDatetime = Datetime.newInstance(startDate, Time.newInstance(9, 0, 0, 0));
        Integer daysAdded = 0;
        Datetime current = startDatetime;

        while (daysAdded < numDays) {
            // Move to the next business day start
            current = BusinessHours.nextStartDate(bhId, current.addDays(1));
            daysAdded++;
        }

        return current.date();
    }

    /**
     * @description Simple business day addition that only skips weekends
     * (Saturday = 6, Sunday = 0 in Salesforce's dayOfWeek convention via
     * DateTime.format('u') where Monday=1, Sunday=7).
     */
    private static Date addBusinessDaysWeekendOnly(Date startDate, Integer numDays) {
        Date current = startDate;
        Integer daysAdded = 0;

        while (daysAdded < numDays) {
            current = current.addDays(1);
            if (isWeekday(current)) {
                daysAdded++;
            }
        }

        return current;
    }

    /**
     * @description Calculates the number of business days between two dates (exclusive
     * of startDate, inclusive of endDate). Returns 0 if dates are null or start >= end.
     * @param startDate The start of the range
     * @param endDate The end of the range
     * @return The count of business days between the two dates
     */
    public static Integer getBusinessDaysBetween(Date startDate, Date endDate) {
        if (startDate == null || endDate == null || startDate >= endDate) {
            return 0;
        }

        Id bhId = getDefaultBusinessHoursId();
        Integer count = 0;
        Date current = startDate;

        while (current < endDate) {
            current = current.addDays(1);
            if (bhId != null) {
                if (BusinessHours.isWithin(bhId, Datetime.newInstance(current, Time.newInstance(9, 0, 0, 0)))) {
                    count++;
                }
            } else {
                if (isWeekday(current)) {
                    count++;
                }
            }
        }

        return count;
    }

    /**
     * @description Checks whether the given date falls on a business day.
     * Uses BusinessHours if available; otherwise checks for weekday only.
     * @param d The date to check
     * @return True if the date is a business day
     */
    public static Boolean isBusinessDay(Date d) {
        if (d == null) {
            return false;
        }

        Id bhId = getDefaultBusinessHoursId();

        if (bhId != null) {
            return BusinessHours.isWithin(
                bhId,
                Datetime.newInstance(d, Time.newInstance(9, 0, 0, 0))
            );
        }

        return isWeekday(d);
    }

    /**
     * @description Checks if a date falls on a weekday (Monday-Friday).
     * Uses DateTime formatting to determine the ISO day of week.
     * @param d The date to check
     * @return True if Monday through Friday
     */
    private static Boolean isWeekday(Date d) {
        // Convert to DateTime, then format to get the day of week
        // toStartOfWeek() returns the locale's start of week; use math instead
        Datetime dt = Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0));
        // 'u' format: 1=Monday ... 7=Sunday (ISO-8601)
        String dayOfWeek = dt.format('u');
        // Saturday=6, Sunday=7
        return dayOfWeek != '6' && dayOfWeek != '7';
    }
}
