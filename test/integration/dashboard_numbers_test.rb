require "test_helper"

# The footer's store link, the transcript's hours and the day count on Today.
class DashboardNumbersTest < ActionDispatch::IntegrationTest
  test "the footer links to the store only when a course can be bought" do
    Course.sold.update_all(price_cents: nil)
    get root_path
    assert_select "footer a[href=?]", store_path, 0

    courses(:px1).update!(price_cents: 2900, published: false)
    get root_path
    assert_select "footer a[href=?]", store_path, 0

    courses(:px1).update!(published: true)
    get root_path
    assert_select "footer a[href=?]", store_path, text: "Courses for sale"
  end

  test "transcript hours show as written, and the day counts from the transcript's Day 1" do
    user = users(:owner)
    user.create_transcript_snapshot!(current_day: 1, day_one: Date.new(2026, 11, 10), hours_logged: 0.75, stage_hours_target: 555,
                                     next_gate_name: "Gate 1", next_gate_day: 30)
    user.course_records.create!(code: "CS 090", title: "Computing Orientation", hours_logged: 0.75, hours_target: 20, status: "In progress")
    assert_equal BigDecimal("0.75"), user.transcript_snapshot.reload.hours_logged

    travel_to Time.zone.local(2026, 11, 12, 9) do
      assert_equal 3, user.transcript_snapshot.day_today
      sign_in_as user
      get portal_path
      assert_response :success
      assert_includes response.body, "Day 3"
      assert_includes response.body, "0.75 of 555 stage hours"
      assert_includes response.body, "0.75 of 20 hours"
      assert_no_match(/0\.8 of/, response.body)
    end
  end

  test "with no Day 1 date the synced day is shown" do
    snap = TranscriptSnapshot.new(current_day: 7)
    assert_equal 7, snap.day_today
  end
end
