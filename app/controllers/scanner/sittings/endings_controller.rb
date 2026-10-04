# Ends the account's scanner sitting after a confirmation page (spec 009 AC-3.5): the copies stay, the list goes, and the
# scanner shows a one-time summary of how many cards the sitting added. The summary rides in the flash and isn't stored.
class Scanner::Sittings::EndingsController < ApplicationController
  def new
    sitting = Current.account.scanner_sitting
    return redirect_to(scanner_path) unless sitting

    @count = sitting.entries.kept.count
  end

  def create
    sitting = Current.account.scanner_sitting
    flash[:sitting_summary] = sitting.end! if sitting
    redirect_to scanner_path, status: :see_other
  end
end
