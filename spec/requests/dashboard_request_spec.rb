# frozen_string_literal: true

require "rails_helper"

RSpec.describe "dashboard controller", :default_creates do
  describe "GET #show" do
    describe "as a teacher" do
      before do
        create(:enrollment, classroom: classroom, user: teacher)
        sign_in teacher
        get dashboard_path
      end

      it "marks My Classes as the current page" do
        expect(Capybara.string(response.body))
          .to have_css("#navbar-main .nav-link.active[aria-current='page'][href='#{dashboard_path}']", exact_text: "My Classes")
      end

      it "holds the page, but not the navbar, in the main landmark" do
        expect(Capybara.string(response.body)).to have_css("main")
          .and have_no_css("main #navbar-main")
      end

      it "does not show the School menu" do
        expect(Capybara.string(response.body)).to have_no_css("#school-menu")
      end

      it "lists the classroom under My Classes" do
        expect(Capybara.string(response.body)).to have_css("#classroomTable tr[data-classroom='#{classroom.id}']")
      end

      it "links to the set homework form for the classroom" do
        expect(Capybara.string(response.body))
          .to have_link("Set Homework", href: new_classroom_homework_path(classroom))
      end

      it "does not show challenge points" do
        expect(Capybara.string(response.body)).to have_no_css("#challenge-points")
      end

      context "with a classroom in the school the teacher is not enrolled in" do
        let!(:other_classroom) { create(:classroom, school: school) }

        before { get dashboard_path }

        it "splits the classrooms between My Classes and Other Classrooms" do
          expect(Capybara.string(response.body))
            .to have_css("#otherClassroomTable tr[data-classroom='#{other_classroom.id}']")
            .and have_no_css("#otherClassroomTable tr[data-classroom='#{classroom.id}']")
            .and have_no_css("#classroomTable tr[data-classroom='#{other_classroom.id}']")
        end
      end
    end

    describe "as a school admin" do
      before do
        create(:enrollment, classroom: classroom, user: school_admin)
        sign_in school_admin
        get dashboard_path
      end

      it "links to My Classes" do
        expect(Capybara.string(response.body)).to have_link("My Classes", href: dashboard_path)
      end

      it "lists the school pages under the School menu" do
        expect(Capybara.string(response.body).find("#school-menu"))
          .to have_link("Overview", href: school_path(school))
          .and have_link("Users", href: users_path)
          .and have_link("Classrooms", href: classrooms_path)
      end

      it "leaves the School menu unmarked" do
        expect(Capybara.string(response.body)).to have_no_css("#school-menu .dropdown-toggle.active")
      end
    end

    # The hidden #oAuthEmail input is what starts the "link your account" tour in the browser
    describe "the Google account link prompt" do
      context "with an unlinked student account" do
        let(:unlinked_student) { create(:student, :no_oauth, school: school) }

        before do
          sign_in unlinked_student
          get dashboard_path
        end

        it "marks the page for the prompt" do
          expect(Capybara.string(response.body)).to have_css("#oAuthEmail", visible: :all)
        end
      end

      context "with a linked student account" do
        before do
          sign_in student
          get dashboard_path
        end

        it "does not mark the page for the prompt" do
          expect(Capybara.string(response.body)).to have_no_css("#oAuthEmail", visible: :all)
        end
      end

      context "with an unlinked teacher account" do
        let(:unlinked_teacher) { create(:teacher, :no_oauth, school: school) }

        before do
          sign_in unlinked_teacher
          get dashboard_path
        end

        it "marks the page for the prompt" do
          expect(Capybara.string(response.body)).to have_css("#oAuthEmail", visible: :all)
        end
      end

      context "with a linked teacher account" do
        it "does not mark the page for the prompt"
      end
    end

    describe "as a student" do
      before { sign_in student }

      describe "the subject carousel" do
        context "with a subject that has its own image" do
          let(:computer_science) { create(:computer_science) }
          let(:computer_science_classroom) { create(:classroom, subject: computer_science, school: school) }

          before do
            create(:enrollment, classroom: computer_science_classroom, user: student)
            get dashboard_path
          end

          it "links the subject's image to its topic select page" do
            expect(Capybara.string(response.body))
              .to have_css("a[href='#{new_quiz_path(subject: "Computer Science")}'] img[src*='computer-science']")
          end
        end

        context "with a subject that has no image of its own" do
          before do
            create(:enrollment, classroom: classroom, user: student)
            get dashboard_path
          end

          it "shows the default subject image" do
            expect(Capybara.string(response.body)).to have_css("img[src*='default-subject']")
          end
        end
      end

      context "with challenge points" do
        before do
          student.update!(challenge_points: 25)
          get dashboard_path
        end

        it "shows them in the nav bar" do
          expect(Capybara.string(response.body)).to have_css("#challenge-points", exact_text: "25")
        end
      end

      describe "the challenge table" do
        let!(:student_enrollment) { create(:enrollment, classroom: classroom, user: student) }
        let!(:challenge) { create(:challenge, topic: topic) }
        let(:challenge_row) { "#challenge-table tr[data-challenge='#{challenge.id}']" }
        let(:progress_cell) { "#{challenge_row} td:nth-child(2)" }

        context "with no challenge progress" do
          before { get dashboard_path }

          it "lists the challenge without a tick" do
            expect(Capybara.string(response.body)).to have_css(challenge_row)
              .and have_no_css("#{progress_cell} i.fa-check")
          end
        end

        context "with a progressed challenge" do
          let!(:progress) { create(:challenge_progress, user: student, challenge: challenge, progress: 70) }

          before { get dashboard_path }

          it "shows the progress" do
            expect(Capybara.string(response.body)).to have_css(progress_cell, exact_text: "70")
          end
        end

        context "with a completed challenge" do
          let!(:progress) do
            create(:challenge_progress, user: student, challenge: challenge, progress: 100, completed: true)
          end

          before { get dashboard_path }

          it "shows a tick" do
            expect(Capybara.string(response.body)).to have_css("#{progress_cell} i.fa-check")
          end
        end

        context "with a challenge in a subject the student is not enrolled in" do
          let!(:other_challenge) { create(:challenge) }

          before { get dashboard_path }

          it "hides that challenge" do
            expect(Capybara.string(response.body)).to have_css(challenge_row)
              .and have_no_css("#challenge-table tr[data-challenge='#{other_challenge.id}']")
          end
        end
      end

      describe "the homework table" do
        let!(:student_enrollment) { create(:enrollment, classroom: classroom, user: student) }
        let!(:homework) { create(:homework, classroom: classroom, topic: topic) }
        let(:homework_row) { ".homework-row[data-homework='#{homework.id}']" }
        let(:name_cell) { "#{homework_row} td:nth-child(2)" }
        let(:status_cell) { "#{homework_row} td:last-child" }

        context "with an active homework" do
          before { get dashboard_path }

          it "names the row after the topic" do
            expect(Capybara.string(response.body)).to have_css(name_cell, exact_text: topic.name)
          end

          it "shows a cross icon" do
            expect(Capybara.string(response.body)).to have_css("#{status_cell} i.fa-times")
              .and have_no_css("#{status_cell} i.fa-exclamation")
          end

          it "shows no tick icon" do
            expect(Capybara.string(response.body)).to have_no_css("#{status_cell} i.fa-check")
          end
        end

        context "when the homework is completed" do
          before do
            homework.homework_progresses.find_by!(user: student).update!(completed: true)
            get dashboard_path
          end

          it "shows a tick icon" do
            expect(Capybara.string(response.body)).to have_css("#{status_cell} i.fa-check")
          end
        end

        context "when the homework is overdue" do
          let!(:homework) { create(:homework, :overdue, classroom: classroom, topic: topic) }

          before { get dashboard_path }

          it "shows an exclamation icon" do
            expect(Capybara.string(response.body)).to have_css("#{status_cell} i.fa-exclamation")
          end
        end

        context "when the homework was completed more than a week ago" do
          let!(:homework) { create(:homework, :overdue, classroom: classroom, topic: topic, due_date: 2.weeks.ago) }

          before do
            homework.homework_progresses.find_by!(user: student).update!(completed: true)
            get dashboard_path
          end

          it "hides the homework" do
            expect(Capybara.string(response.body)).to have_no_css(homework_row)
          end
        end

        context "with a second homework due later" do
          let!(:later_homework) { create(:homework, due_date: 8.days.from_now, classroom: classroom, topic: topic) }

          before { get dashboard_path }

          it "orders the rows by due date" do
            expect(Capybara.string(response.body)).to have_css(".homework-row:first-child[data-homework='#{homework.id}']")
              .and have_css(".homework-row:nth-child(2)[data-homework='#{later_homework.id}']")
          end
        end

        context "with 16 outstanding homeworks" do
          let!(:more_homeworks) { create_list(:homework, 15, classroom: classroom, topic: topic) }

          before { get dashboard_path }

          it "lists 15" do
            expect(Capybara.string(response.body)).to have_css("tr.homework-row", count: 15)
          end
        end

        context "when the homework is for a lesson" do
          let(:lesson) { create(:lesson, topic: topic, title: "Cell division") }
          let!(:homework) { create(:homework, classroom: classroom, topic: topic, lesson: lesson) }

          before { get dashboard_path }

          it "names the row after the lesson" do
            expect(Capybara.string(response.body)).to have_css(name_cell, exact_text: "Cell division")
          end
        end

        context "with a homework in another classroom" do
          let!(:other_homework) { create(:homework) }

          before { get dashboard_path }

          it "hides that homework" do
            expect(Capybara.string(response.body)).to have_css(homework_row)
              .and have_no_css(".homework-row[data-homework='#{other_homework.id}']")
          end
        end
      end
    end

    describe "as a student with an equipped dashboard style" do
      let!(:active_customisation) do
        create(:active_customisation, user: student,
          customisation: create(:dashboard_customisation, value: "orange"))
      end

      before do
        sign_in student
        get dashboard_path
      end

      it "colours every section separator, leaving none on the red default" do
        expect(Capybara.string(response.body)).to have_css(".heading-divider[style*='orange']")
          .and have_no_css(".heading-divider[style*='red']")
      end

      it "backs the homework section with the style's image" do
        expect(Capybara.string(response.body))
          .to have_css("#homework.homework-image[style*='background']")
      end
    end
  end
end
